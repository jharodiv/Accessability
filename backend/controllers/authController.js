const jwt = require('jsonwebtoken');
const User = require('../models/User'); // Assuming you have a User model
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');

// Signup controller
exports.signup = catchAsync(async (req, res, next) => {
    const { uid, userName, email, contactNumber } = req.body;

    // Check if user already exists
    let user = await User.findOne({ userName });
    if (user) {
        return next(new AppError('User already exists', 400));
    }

    // Create new user
    user = new User({
        uid,
        userName,
        email,
        contactNumber
    });

    await user.save();

    // Generate JWT token
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_LIFETIME });

    // Send response
    res.status(200).json({
        status: 'success',
        token,
        data: {
            user: {
                id: user._id,
                uid: user.uid,
                username: user.userName,
                email: user.email,
                contactNumber: user.contactNumber
            },
        },
    });
});

// Login controller
exports.login = catchAsync(async (req, res, next) => {
    const { uid, email } = req.body;

    // Validate input
    if (!uid || !email) {
        return next(new AppError('Please provide both UID and email', 400));
    }

    // Check if the user exists
    const user = await User.findOne({ uid, email });
    if (!user) {
        return next(new AppError('Invalid credentials', 401)); // 401 for unauthorized
    }

    // Generate JWT token
    const token = jwt.sign({ userId: user._id }, process.env.JWT_SECRET, {
        expiresIn: process.env.JWT_LIFETIME,
    });

    // Send response
    res.status(200).json({
        status: 'success',
        token,
        data: {
            user: {
                id: user._id,
                uid: user.uid,
                email: user.email,
            },
        },
    });
});
