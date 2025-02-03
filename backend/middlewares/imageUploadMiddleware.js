const cloudinary = require('cloudinary').v2;
require('dotenv').config({ path: './config.env' });
const multer = require('multer');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const AppError = require('../utils/appError');
const catchAsync = require('../utils/catchAsync');

// Cloudinary configuration
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// Cloudinary Storage Configuration with Required Format
const storage = new CloudinaryStorage({
  cloudinary,
  params: async (req, file) => {
    const publicId = `profile_${Date.now()}`; // Unique filename based on timestamp
    return {
      folder: 'uploads/profiles',
      allowed_formats: ['jpg', 'png'],
      public_id: publicId,
      unique_filename: false, // Prevent Cloudinary from generating unique filenames
      resource_type: 'image',
      transformation: [
        { fetch_format: 'auto', quality: 'auto' },
        { crop: 'fill', gravity: 'auto' }, // Auto-crop based on the subject
      ],
    };
  },
});

// Multer configuration
exports.upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // Max file size (10MB)
});

// Middleware to Handle Image Upload & Delete Old Profile Picture
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
        new AppError('Error deleting old profile picture: ' + error.message, 500)
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
