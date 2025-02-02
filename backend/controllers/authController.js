const User = require('../models/User');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');

// Signup controller
exports.signup = catchAsync(async (req, res, next) => {
  console.log("Line 6: Received signup request with data:", req.body); // Debug log

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

  console.log("Line 24: Prepared user data:", userData); // Debug log

  try {
    console.log("Line 26: Attempting to create a new user..."); // Debug log
    const user = await User.create(userData);
    console.log("Line 28: User created successfully:", user); // Debug log

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
    console.error("Line 36: Error creating user:", err); // Debug log

    if (err.code === 11000 && err.keyValue.email) {
      console.log("Line 39: Email already exists."); // Debug log
      return next(new AppError('Email already exists', 400));
    }
    return next(new AppError('User Creation failed', 400));
  }
  console.warn("Line 43: User created successfully", userData); // Debug log
});

// Login controller
exports.login = catchAsync(async (req, res, next) => {
  console.log("Line 51: Received login request with data:", req.body); // Debug log
  const { email, password, confirmPassword } = req.body;

  // Validate input: ensure both email and password are provided
  if (!email || !password) {
    console.log("Line 54: Missing email or password"); // Debug log
    return next(new AppError('Please provide both email and password', 400));
  }

  if (password !== confirmPassword) {
    console.log("Line 58: Passwords do not match"); // Debug log
    return next(new AppError('Passwords do not match', 400));
  }

  // Check if the user exists and compare the password
  console.log("Line 62: Searching for user with email:", email); // Debug log
  const user = await User.findOne({ email });
  if (!user || !(await user.comparePassword(password))) {
    console.log("Line 66: Invalid credentials for email:", email); // Debug log
    return next(new AppError('Invalid credentials', 401)); // Unauthorized
  }

  // Generate a JWT token for the user
  console.log("Line 70: Generating JWT for the user..."); // Debug log
  const token = user.createJWT();

  // Send the response with the token
  console.log("Line 73: Sending success response with token"); // Debug log
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
