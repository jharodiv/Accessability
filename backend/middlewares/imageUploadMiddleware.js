const cloudinary = require('cloudinary').v2;
require('dotenv').config({ path: './config.env' });
const multer = require('multer');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const AppError = require('../utils/appError');
const catchAsync = require('../utils/catchAsync'); // Import catchAsync

// Cloudinary configuration
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// Cloudinary Storage Configuration
const storage = new CloudinaryStorage({
  cloudinary,
  params: {
    folder: 'uploads/profiles',
    allowed_formats: ['jpg', 'png'],
    public_id: (req, file) => `profile_${Date.now()}`, // Unique filename
    transformation: [{ width: 500, height: 500, crop: 'limit' }],
    resource_type: 'image',
  },
});

// Multer configuration
exports.upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // Set max file size (10MB in this case)
});

// Middleware to handle image upload & delete old profile picture
exports.imageUploadMiddleware = catchAsync(async (req, res, next) => {
  console.log('Starting image upload middleware...');

  // Ensure `details` exists in the request body
  if (!req.body.details) {
    req.body.details = {};
    console.log('No details found in request body. Initializing details...');
  }

  // If user already has a profile picture, delete the old one
  if (req.body.details.profilePicture) {
    const oldImageUrl = req.body.details.profilePicture;
    const publicId = oldImageUrl.split('/').pop().split('.')[0]; // Extract public ID
    console.log('Deleting old profile picture:', oldImageUrl);

    try {
      await cloudinary.uploader.destroy(`uploads/profiles/${publicId}`);
      console.log('Old profile picture deleted.');
    } catch (error) {
      console.error('Error deleting old profile picture:', error.message);
      return next(
        new AppError(
          'Error deleting old profile picture: ' + error.message,
          500,
        ),
      );
    }
  }

  // Set the new uploaded image URL if file is present
  if (req.file) {
    req.body.details.profilePicture = req.file.path;
    console.log('New profile picture set:', req.file.path);
  }

  // Proceed to the next middleware
  next();
});
