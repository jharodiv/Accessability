const User = require('../models/User');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');
const sendEmail = require('../utils/email');

// Signup controller
exports.signup = catchAsync(async (req, res, next) => {
  console.log('Line 6: Received signup request with data:', req.body); // Debug log

  const userData = {
    name: req.body.name,
    email: req.body.email,
    password: req.body.password,
    details: {
      ...req.body.details,
      profilePicture: req.body.details?.profilePicture || null,
    },
    settings: {
      ...req.body.settings,
      verificationCode: req.body.settings?.verificationCode || null,
      codeExpiresAt: req.body.settings?.codeExpiresAt || null,
      verified:
        req.body.settings?.verified !== undefined
          ? req.body.settings.verified
          : false,
      passwordChangedAt: req.body.settings?.passwordChangedAt || null,
      passwordResetToken: req.body.settings?.passwordResetToken || null,
      passwordResetExpiresAt: req.body.settings?.passwordResetExpiresAt || null,
      active:
        req.body.settings?.active !== undefined
          ? req.body.settings.active
          : true,
    },
  };

  console.log('Line 24: Prepared user data:', userData); // Debug log

  try {
    console.log('Line 26: Attempting to create a new user...'); // Debug log
    const user = await User.create(userData);
    console.log('Line 28: User created successfully:', user); // Debug log

    const token = user.createJWT();
    res.status(201).json({
      status: 'success',
      token,
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
    console.error('Line 36: Error creating user:', err); // Debug log

    if (err.code === 11000 && err.keyValue.email) {
      console.log('Line 39: Email already exists.'); // Debug log
      return next(new AppError('Email already exists', 400));
    }
    return next(new AppError('User Creation failed', 400));
  }
  console.warn('Line 43: User created successfully', userData); // Debug log
});

// Login controller
exports.login = catchAsync(async (req, res, next) => {
  console.log('Line 51: Received login request with data:', req.body); // Debug log
  const { email, password } = req.body;

  // Validate input: ensure both email and password are provided
  if (!email || !password) {
    console.log('Line 54: Missing email or password'); // Debug log
    return next(new AppError('Please provide both email and password', 400));
  }

  // Check if the user exists and compare the password
  console.log('Line 58: Searching for user with email:', email); // Debug log
  const user = await User.findOne({ email });
  if (!user || !(await user.comparePassword(password))) {
    console.log('Line 62: Invalid credentials for email:', email); // Debug log
    return next(new AppError('Invalid credentials', 401)); // Unauthorized
  }

  // Generate a JWT token for the user
  console.log('Line 66: Generating JWT for the user...'); // Debug log
  const token = user.createJWT();

  // Send the response with the token
  console.log('Line 69: Sending success response with token'); // Debug log
  res.status(200).json({
    status: 'success',
    token,
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
});

// ** Send Verification Code controller
exports.sendVerificationCode = catchAsync(async (req, res, next) => {
  const user = await User.findOne({ email: req.body.email });

  if (!user) {
    return next(new AppError('User not found with this email.', 404));
  }

  const verificationCode = user.createVerificationCode();
  await user.save({ validateBeforeSave: false });

  try {
    await sendEmail({
      email: user.email,
      subject: 'Your Verification Code',
      verificationCode: verificationCode,
      type: 'verification',
    });
    res.status(200).json({
      status: 'success',
      message: 'Verification code sent to email!',
    });
  } catch (err) {
    user.verificationCode = undefined;
    user.codeExpires = undefined;
    await user.save({ validateBeforeSave: false });

    return next(
      new AppError('Error sending verification code. Try again later.', 500),
    );
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
