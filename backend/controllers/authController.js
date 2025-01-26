const jwt = require('jsonwebtoken');
const User = require('../models/User');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');

// Signup controller
exports.signup = catchAsync(async (req, res, next) => {
    const { name, email, password, role, accessibilityProfile } = req.body;

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
        role,
        accessibilityProfile
    });

    await user.save();

    // Generate JWT token
    const token = user.createJWT();

    // Send response
    res.status(201).json({
        status: 'success',
        token,
        data: {
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                role: user.role,
                accessibilityProfile: user.accessibilityProfile
            },
        },
    });
});

// Login controller
exports.login = catchAsync(async (req, res, next) => {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
        return next(new AppError('Please provide both email and password', 400));
    }

    // Check if the user exists and password is correct
    const user = await User.findOne({ email });
    if (!user || !(await user.comparePassword(password))) {
        return next(new AppError('Invalid credentials', 401)); // 401 for unauthorized
    }

    // Generate JWT token
    const token = user.createJWT();

    // Send response
    res.status(200).json({
        status: 'success',
        token,
        data: {
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                role: user.role,
                accessibilityProfile: user.accessibilityProfile
            },
        },
    });
});
