const express = require('express');
const authController = require('../controllers/authController');
const { upload } = require('../middlewares/imageUploadMiddleware');

const router = express.Router();

// ** Signup route
router.post('/signup', upload.single('image'), authController.signup);

// ** Login route
router.post('/login', authController.login);

// ** Send verification route
router.post('/sendVerificationCode', authController.sendVerificationCode);

// ** Verify route
router.post('/verifyCode', authController.verifyCode);
router.post('/resendCode', authController.resendVerificationCode);

module.exports = router;
