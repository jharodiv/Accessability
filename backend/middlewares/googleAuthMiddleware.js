const speakeasy = require('speakeasy');

// Middleware to verify Google Authenticator OTP
exports.verifyGoogleAuthToken = (req, res, next) => {
  const { token } = req.body;
  const user = req.user; // Assuming the user is already authenticated

  if (!user || !user.googleAuthSecret) {
    return res.status(400).json({ message: 'Google Authenticator not set up for this user' });
  }

  // Verify OTP
  const isTokenValid = speakeasy.totp.verify({
    secret: user.googleAuthSecret,
    encoding: 'base32',
    token,
  });

  if (!isTokenValid) {
    return res.status(400).json({ message: 'Invalid Google Authenticator token' });
  }

  next(); // If the token is valid, continue with the request
};
