const jwt = require('jsonwebtoken');
const User = require('../models/User');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');

// Signup controller
exports.signup = catchAsync(async (req, res, next) => {
  const { name, email, password, contactNumber } = req.body;

  // Check if user already exists
  let user = await User.findOne({ email });
  if (user) {
    return next(new AppError('User already exists', 400));
  }

  // Create new user
  user = new User({
    name,
    email,
    password,
    contactNumber,
  });

  // Save the user to the database
  await user.save();

  // Generate JWT token
  const jwtToken = user.createJWT();

  // Send response with the token
  res.status(201).json({
    status: 'success',
    token: jwtToken,
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
