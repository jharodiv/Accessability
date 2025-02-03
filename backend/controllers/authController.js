const User = require('../models/User');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');
const sendEmail = require('../utils/email');
const crypto = require('crypto');

// Signup controller
exports.signup = catchAsync(async (req, res, next) => {
  console.log('Received signup request with data:', req.body); // Debug log

  const userData = {
    name: req.body.name,
    email: req.body.email,
    password: req.body.password,
    details: {
      ...req.body.details,
      profilePicture: req.body.details?.profilePicture || null,
    },
    settings: {
      verificationCode: null, // Will be set after signup
      codeExpires: null, // Will be set after signup
      verified: false,
      passwordChangedAt: null,
      passwordResetToken: null,
      passwordResetExpiresAt: null,
      active: true,
    },
  };

  try {
    console.log('Attempting to create a new user...');
    const user = await User.create(userData);
    console.log('User created successfully:', user);

    const token = user.createJWT();

    // Create a verification code and set expiry
    const verificationCode = user.createVerificationCode();
    user.verificationCode = verificationCode;
    user.codeExpires = Date.now() + 10 * 60 * 1000; // Code expires in 10 minutes
    await user.save({ validateBeforeSave: false });

    // Send verification code email
    try {
      await sendEmail({
        email: user.email,
        subject: 'Your Verification Code',
        verificationCode: verificationCode,
        type: 'verification',
      });
      console.log('Verification code sent to email!');

      res.status(201).json({
        status: 'success',
        token,
        message: 'Verification code sent to email!',
        data: {
          user: {
            id: user._id,
            name: user.name,
            email: user.email,
            details: user.details,
            settings: user.settings,
          },
        },
      });
    } catch (err) {
      user.verificationCode = undefined;
      user.codeExpires = undefined;
      await user.save({ validateBeforeSave: false });
      return next(
        new AppError('Error sending verification code. Try again later.', 500),
      );
    }
  } catch (err) {
    console.error('Error creating user:', err);
    if (err.code === 11000 && err.keyValue.email) {
      return next(new AppError('Email already exists', 400));
    }
    return next(new AppError('User creation failed', 400));
  }
});

// ** Verify code controller
exports.verifyCode = catchAsync(async (req, res, next) => {
  const { email, code } = req.body;

  const hashedCode = crypto.createHash('sha256').update(code).digest('hex');

  // Find user by email and verification code, ensuring code has not expired
  const user = await User.findOne({
    email,
    verificationCode: hashedCode,
    codeExpires: { $gt: Date.now() }, // Ensure the code has not expired
  });

  if (!user) {
    return next(new AppError('Invalid or expired verification code.', 400));
  }

  user.verified = true;
  user.verificationCode = undefined;
  user.codeExpires = undefined;

  await user.save({ validateBeforeSave: false });

  res.status(200).json({
    status: 'success',
    message: 'User successfully verified!',
  });
});
