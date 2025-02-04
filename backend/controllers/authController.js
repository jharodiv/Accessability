const crypto = require('crypto'); // Import the crypto module
const User = require('../models/User');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');
const sendEmail = require('../utils/email');
const {
  imageUploadMiddleware,
} = require('../middlewares/imageUploadMiddleware');

// ** Send Token
const createSendToken = (user, statusCode, res, additionalData = {}) => {
  const token = user.createJWT();
  const cookieOptions = {
    expires: new Date(
      Date.now() + process.env.JWT_COOKIE_EXPIRES_IN * 24 * 60 * 60 * 1000,
    ),
    secure: true,
    httpOnly: true,
  };
  if (process.env.NODE_ENV === 'production') cookieOptions.secure = true;

  //! Send the token and additional data to the client
  res.cookie('jwt', token, cookieOptions);
  res.status(statusCode).json({
    status: 'success',
    token,
    ...additionalData,
  });
};

// ** Signup controller
exports.signup = catchAsync(async (req, res, next) => {
  console.log('Line 6: Received signup request with data:', req.body); // Debug log
  console.log('Line 7: File received in signup request:', req.file);

  // Default profile picture URL (update this path if needed)
  const DEFAULT_PROFILE_PICTURE =
    'https://res.cloudinary.com/dfenjj2vs/image/upload/v1738594296/1ffe033b103737d30ee1c98c1d9c51a6_nv95n5.png';

  let profilePicture = DEFAULT_PROFILE_PICTURE; // Set default initially

  // Handle image upload if a file is provided
  if (req.file) {
    console.log('Line 17: Image upload detected, processing image...'); // Debug log
    await imageUploadMiddleware(req, res, async (err) => {
      if (err) {
        console.log('Line 21: Error in image upload middleware:', err); // Debug log
        return next(new AppError(err.message, 400));
      }

      if (req.file && req.file.path) {
        console.log('Line 27: Updating profile picture:', req.file.path); // Debug log
        profilePicture = req.file.path;
      }
    });
  }

  const userData = {
    name: req.body.name,
    email: req.body.email,
    password: req.body.password,
    details: {
      ...req.body.details,
      profilePicture: profilePicture, // Use uploaded image or default
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
});

// ** Login controller
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

// ** Resend Verification Code controller (implementing the missing functionality)
exports.resendVerificationCode = catchAsync(async (req, res, next) => {
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
      message: 'Verification code resent to email!',
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
