const admin = require('firebase-admin');

// Initialize Firebase Admin SDK (if not already done)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

const db = admin.firestore();

exports.verifyCode = catchAsync(async (req, res, next) => {
  const { email, verificationCode } = req.body;

  // Fetch user data from Firestore
  const userRef = db.collection('Users').doc(email);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    return next(new AppError('User not found with this email.', 404));
  }

  const user = userDoc.data();

  // Check if the verification code is expired
  if (user.codeExpires < Date.now()) {
    return next(new AppError('Verification code expired.', 400));
  }

  // Hash the entered code and compare with the stored one
  const hashedCode = crypto
    .createHash('sha256')
    .update(verificationCode)
    .digest('hex');

  if (hashedCode !== user.settings.verificationCode) {
    return next(new AppError('Invalid verification code.', 400));
  }

  // Mark the user as verified
  await userRef.update({
    'settings.verified': true,
    'settings.verificationCode': admin.firestore.FieldValue.delete(),
    'settings.codeExpires': admin.firestore.FieldValue.delete(),
  });

  res.status(200).json({
    status: 'success',
    message: 'Verification successful!',
  });
});