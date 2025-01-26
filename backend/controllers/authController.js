const jwt = require('jsonwebtoken');
const User = require('../models/User');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');

// Signup controller
exports.signup = catchAsync(async (req, res, next) => {
  const userData = {
    name: req.body.name,
    email: req.body.email,
    contactNumber: req.body.contactNumber,
    password: req.body.password,
    profile: req.body.profile || null,
    details: req.body.details || {},
    settings: {
      ...req.body.settings, 
      verificationCode: req.body.settings?.verificationCode || null,
      codeExpiresAt: req.body.settings?.codeExpiresAt || null,
      verified: req.body.settings?.verified !== undefined ? req.body.settings.verified : false,
      passwordChangedAt: req.body.settings?.passwordChangedAt || null,
      passwordResetToken: req.body.settings?.passwordResetToken || null,
      passwordResetExpiresAt: req.body.settings?.passwordResetExpiresAt || null,
      active: req.body.settings?.active !== undefined ? req.body.settings.active : true,
    },
  };
  try {
    const user = await User.create(userData);
    const token = user.createJWT();
    res.status(201).json({
      status: 'success',
      token,
      data: {
        user: {
          id: user._id,
          name: user.name,
          email: user.email,
          contactNumber: user.contactNumber,
          details: user.details,
          settings: user.settings,
        },
      },
    });
  } catch (err) {
    if (err.code === 11000 && err.keyValue.email) {
      return next(new AppError('Email already exists', 400));
    }
    return next(new AppError('User Creation failed', 400));
  }
  console.warn('User created successfully', userData);
  
});

exports.login = catchAsync(async (req, res, next) => {
  const { email, password, confirmPassword } = req.body;

  // Validate input: ensure both email and password are provided
  if (!email || !password) {
    return next(new AppError('Please provide both email and password', 400));
  }

  if (password !== confirmPassword) {
    return next(new AppError('Passwords do not match', 400));
  }

  // Check if the user exists and compare the password
  const user = await User.findOne({ email });
  if (!user || !(await user.comparePassword(password))) {
    return next(new AppError('Invalid credentials', 401)); // Unauthorized
  }

  // Generate a JWT token for the user
  const token = user.createJWT();

  // Send the response with the token
  res.status(200).json({
    status: 'success',
    token, // Send the token in the response
    data: {
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        contactNumber: user.contactNumber,
      },
    },
  });
});
