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
  console.log('Received signup request with data:', req.body);
  console.log('File received in signup request:', req.file);

  // Default profile picture URL
  const DEFAULT_PROFILE_PICTURE =
    'https://res.cloudinary.com/dfenjj2vs/image/upload/v1738594296/1ffe033b103737d30ee1c98c1d9c51a6_nv95n5.png';

  let profilePicture = DEFAULT_PROFILE_PICTURE;

  // Handle image upload if a file is provided
  if (req.file) {
    console.log('Image upload detected, processing image...');
    await imageUploadMiddleware(req, res, async (err) => {
      if (err) {
        console.log('Error in image upload middleware:', err);
        return next(new AppError(err.message, 400));
      }
      if (req.file.path) {
        console.log('Updating profile picture:', req.file.path);
        profilePicture = req.file.path;
      }
    });
  }

  // Validate required fields (name, email, password, phoneNumber)
  const { name, email, password, phoneNumber, address } = req.body;
  if (!name || !email || !password || !phoneNumber) {
    return next(
      new AppError(
        'Name, email, password, and phone number are required.',
        400,
      ),
    );
  }

  // Log to check phoneNumber value
  console.log('Phone number received:', phoneNumber);

  // Add phoneNumber and address to user data
  const userData = {
    name,
    email,
    password,
    details: {
      phoneNumber, // Use provided phone number
      address: address || null, // If address is not provided, set as null
      profilePicture, // Use uploaded image or default
    },
    settings: {
      verificationCode: null,
      codeExpiresAt: null,
      verified: false,
      passwordChangedAt: null,
      passwordResetToken: null,
      passwordResetExpiresAt: null,
      active: true,
    },
  };

  console.log('Prepared user data:', userData);

  try {
    console.log('Attempting to create a new user...');
    const user = await User.create(userData);
    console.log('User created successfully:', user);

    const token = user.createJWT();
    res.status(201).json({
      status: 'success',
      token,
      data: {
        user: {
          name: user.name,
          email: user.email,
          details: {
            address: user.details.address,
            phoneNumber: user.details.phoneNumber,
            profilePicture: user.details.profilePicture,
          },
          settings: user.settings, // Return the default settings
        },
      },
    });
  } catch (err) {
    console.error('Error creating user:', err);

    if (err.code === 11000 && err.keyValue.email) {
      console.log('Email already exists.');
      return next(new AppError('Email already exists', 400));
    }
    return next(new AppError('User creation failed', 400));
  }
});

// ** Login controller
// ** Login controller
exports.login = catchAsync(async (req, res, next) => {
  console.log('Line 51: Received login request with data:', req.body); // Debug log

  const { email, password } = req.body;

  // Validate input: ensure both email and password are provided
  if (!email || !password) {
    console.log('Line 54: Missing email or password'); // Debug log
    return next(new AppError('Please provide both email and password', 400));
  }

  // Convert email to lowercase to avoid case-sensitivity issues
  const normalizedEmail = email.toLowerCase();
  console.log('Line 58: Searching for user with email:', normalizedEmail); // Debug log

  // Check if the user exists
  const user = await User.findOne({ email: normalizedEmail });

  if (!user) {
    console.log('Line 61: No user found with email:', normalizedEmail); // Debug log
    return next(new AppError('Invalid credentials', 401)); // Unauthorized
  }

  // Debugging password comparison
  console.log('Stored Hashed Password:', user.password);
  console.log('Entered Password:', password);
  const isPasswordCorrect = await user.comparePassword(password);
  console.log('Comparison Result:', isPasswordCorrect);

  if (!isPasswordCorrect) {
    console.log('Line 68: Incorrect password for email:', normalizedEmail);
    return next(new AppError('Invalid credentials', 401)); // Unauthorized
  }

  if (!user.settings.verified) {
    return next(
      new AppError('Please verify your email before logging in.', 401),
    );
  }

  // Generate a JWT token for the user
  console.log('Line 74: Generating JWT for the user...'); // Debug log
  const token = user.createJWT();

  // Send the response with the token
  console.log('Line 78: Sending success response with token'); // Debug log
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

  // Generate raw verification code and store it in the database (hashed version)
  const verificationCode = user.createVerificationCode();
  await user.save({ validateBeforeSave: false });

  try {
    console.log('Attempting to send email...');
    // Send raw verification code in the email
    await sendEmail({
      email: user.email,
      subject: 'Your Verification Code',
      verificationCode: verificationCode, // raw verification code sent here
      type: 'verification',
    });

    console.log('Email sent successfully!');
    res.status(200).json({
      status: 'success',
      message: 'Verification code sent to email!',
    });
  } catch (err) {
    console.error('Error sending email:', err); // Log the actual error
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
  const { email, verificationCode } = req.body;
  const user = await User.findOne({ email });

  if (!user) {
    return next(new AppError('User not found with this email.', 404));
  }

  // Check if the verification code is expired
  if (user.codeExpires < Date.now()) {
    return next(new AppError('Verification code expired.', 400));
  }

  // Hash the entered code and compare with the stored one
  const hashedCode = crypto
    .createHash('sha256')
    .update(verificationCode)
    .digest('hex');

  if (hashedCode !== user.verificationCode) {
    return next(new AppError('Invalid verification code.', 400));
  }

  // Mark the user as verified
  user.settings.verified = true;
  user.verificationCode = undefined; // Clear the code after verification
  user.codeExpires = undefined; // Clear expiration time
  await user.save({ validateBeforeSave: false });

  res.status(200).json({
    status: 'success',
    message: 'Verification successful!',
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
