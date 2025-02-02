const express = require('express');
const userController = require('../controllers/userController');
const authorizationMiddleware = require('../middlewares/authorizationMiddleware');
const { upload } = require('../middlewares/imageUploadMiddleware');

const router = express.Router();

// Public Route: Get all users
router.get('/', userController.getAllUsers);

// Uncomment if authentication is required for the following routes
// router.use(authorizationMiddleware.protect);

router
  .route('/:id')
  .get(userController.getUser) // Get user by ID
  .patch(upload.single('image'), userController.updateUser) // Update user (use PATCH instead of PUT for partial updates)
  .delete(userController.deleteUser); // Delete user by ID

module.exports = router;
