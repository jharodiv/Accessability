const mongoose = require('mongoose');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');

const connectDB = (url) => {
  if (!url) {
    throw new AppError('No Database URL Found', 404);
  }
  if (process.env.MONGO_PASSWORD) {
    return url.replace('<db_password>', process.env.MONGO_PASSWORD);
  }
  return url;
};

const connectToDatabase = catchAsync(async () => {
  const dbURL = connectDB(process.env.MONGO_EMAIL);

  try {
    await mongoose.connect(dbURL);
    console.log('Database connection is successful');
  } catch (error) {
    console.error('Database connection error:', error);
    throw new AppError('Database connection failed', 500);
  }
});

module.exports = connectToDatabase;
