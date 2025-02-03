const express = require('express');
const authController = require('../controllers/authController');

const router = express.Router();

// ** Signup route
router.post('/signup', authController.signup);

// ** Login route
router.post('/login', authController.login);

// ** Verify route
router.post('/verifyCode', authController.verifyCode);
router.post('/resendCode', authController.resendVerificationCode);

module.exports = router;
