const jwt = require('jsonwebtoken');
const User = require('../models/User'); // Assuming you have a User model
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');

// Signup controller
exports.signup = catchAsync(async (req, res, next) => {
    const { username, password } = req.body;

    // Check if user already exists
    let user = await User.findOne({ username });
    if (user) {
        return next(new AppError('User already exists', 400));
    }

    // Create new user
    user = new User({
        username,
        password
    });

    await user.save();

    // Generate JWT token
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_LIFETIME });

    res.status(201).json({ token });
});

// Login controller
exports.login = catchAsync(async (req, res, next) => {
    const { username, password } = req.body;

    // Check if user exists
    const user = await User.findOne({ username });
    if (!user) {
        return next(new AppError('Invalid credentials', 400));
    }

    // Check password
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
        return next(new AppError('Invalid credentials', 400));
    }

    // Generate JWT token
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_LIFETIME });

    res.json({ token });
});