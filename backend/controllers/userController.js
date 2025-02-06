const User = require('../models/User');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');
const {
  imageUploadMiddleware,
} = require('../middlewares/imageUploadMiddleware');
const jwt = require('jsonwebtoken');

// Get All Users
exports.getAllUsers = catchAsync(async (req, res, next) => {
  console.log('Line 7: Fetching all users...'); // Debug log

  const users = await User.find();

  console.log('Line 10: All users fetched:', users); // Debug log

  res.status(200).json({
    status: 'success',
    results: users.length,
    data: {
      users,
    },
  });
});

// Read User
exports.getUser = catchAsync(async (req, res, next) => {
  console.log('Line 19: Fetching user with ID:', req.params.id); // Debug log

  const user = await User.findById(req.params.id);

  // Check if user exists
  if (!user) {
    console.log('Line 22: User not found with ID:', req.params.id); // Debug log
    return next(new AppError('User not found', 404));
  }

  console.log('Line 27: User found:', user); // Debug log

  res.status(200).json({
    status: 'success',
    data: {
      user,
    },
  });
});

// Update user controller
exports.updateUser = catchAsync(async (req, res, next) => {
  console.log('Line 36: Received request to update user:', req.body); // Debug log
  console.log('Line 37: File received:', req.file); // Debug log

  // Convert req.body to a plain object if it's a 'null prototype' object
  const body = Object.assign({}, req.body);
  console.log('Line 40: Converted req.body to plain object:', body); // Debug log

  // Find the user by ID
  const user = await User.findById(req.params.id);

  // Check if user exists
  if (!user) {
    console.log('Line 46: User not found with ID:', req.params.id); // Debug log
    return next(new AppError('User not found', 404));
  }

  console.log('Line 51: User found:', user); // Debug log

  // Handle image upload middleware (only if an image is present)
  if (req.file) {
    console.log('Line 56: Image upload detected, processing image...'); // Debug log
    await imageUploadMiddleware(req, res, async (err) => {
      // Handle error in image upload middleware
      if (err) {
        console.log('Line 59: Error in image upload middleware:', err); // Debug log
        return next(new AppError(err.message, 400));
      }

      // Update the profile picture if a new one is uploaded
      if (req.file && req.file.path) {
        console.log('Line 64: Updating profile picture:', req.file.path); // Debug log
        user.details.profilePicture = req.file.path;
      }
    });
  }

  // Check if req.body is an object and contains fields to update
  if (body && typeof body === 'object' && Object.keys(body).length > 0) {
    console.log(
      'Line 73: Fields to update detected. Looping through fields...',
    ); // Debug log

    // Loop through the fields in req.body and update the user
    for (const key in body) {
      if (body.hasOwnProperty(key)) {
        console.log(`Line 76: Processing key: ${key}`); // Debug log

        // Skip the createdAt and email fields to prevent them from updating
        if (key === 'createdAt' || key === 'email') {
          console.log(`Line 80: Skipping ${key} field.`); // Debug log
          continue;
        }

        // Check if the key is 'details' or 'settings', and handle nested fields
        if (key === 'details' || key === 'settings') {
          console.log(`Line 85: Handling nested fields under ${key}...`); // Debug log

          // Loop through the nested fields of details/settings and update them
          for (const subKey in body[key]) {
            if (body[key].hasOwnProperty(subKey)) {
              console.log(
                `Line 90: Updating ${key}.${subKey} to ${body[key][subKey]}`,
              ); // Debug log
              user[key][subKey] = body[key][subKey];
            }
          }
        } else {
          console.log(`Line 94: Updating ${key} to ${body[key]}`); // Debug log
          user[key] = body[key];
        }
      }
    }
  } else {
    console.log('Line 99: No fields to update.'); // Debug log
  }

  // If the password was updated, generate a new JWT token
  if (body.password) {
    console.log('Line 104: Password change detected.'); // Debug log
    user.password = body.password; // Update password
    await user.save(); // Save user with the new password

    // Generate new JWT token after password change
    const token = user.createJWT();
    console.log('Line 109: New JWT token generated:', token); // Debug log

    // Send response with the new token
    res.status(200).json({
      status: 'success',
      token,
      data: {
        user,
      },
    });
  } else {
    // If no password change, just update the user and send a success response
    user.updatedAt = Date.now();
    console.log('Line 113: updatedAt set to:', user.updatedAt); // Debug log

    await user.save();

    console.log('Line 116: User updated successfully:', user); // Debug log

    res.status(200).json({
      status: 'success',
      data: {
        user,
      },
    });
  }
});
// Delete User
exports.deleteUser = catchAsync(async (req, res, next) => {
  console.log('Line 118: Deleting user with ID:', req.params.id); // Debug log

  const user = await User.findByIdAndDelete(req.params.id);

  // Check if user exists before deleting
  if (!user) {
    console.log('Line 122: User not found with ID:', req.params.id); // Debug log
    return next(new AppError('User not found', 404));
  }

  console.log('Line 126: User deleted successfully.'); // Debug log

  res.status(204).json({
    status: 'success',
    data: null,
  });
});

//!! BOARDING
exports.updateHasCompletedOnboarding = catchAsync(async (req, res, next) => {
  console.log('Received request to update user:', req.body);
  console.log('Checking req.user:', req.user ? req.user : 'User is undefined');

  if (!req.user || !req.user.id) {
    console.error('Error: req.user is undefined or missing ID');
    return next(new AppError('User not authenticated', 401));
  }

  const updatedUser = await User.findByIdAndUpdate(
    req.user.id,
    { $set: { 'settings.hasCompletedOnboarding': true } },
    { new: true, runValidators: true },
  );

  if (!updatedUser) {
    return next(new AppError('No user found with that ID', 404));
  }

  res.status(200).json({
    status: 'success',
    data: { user: updatedUser },
  });
});
