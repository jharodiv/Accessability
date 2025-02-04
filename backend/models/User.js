const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
    validate: {
      validator: function (v) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
      },
      message: (props) => `${props.value} is not a valid email address!`,
    },
  },
  password: {
    type: String,
    required: true,
  },
  details: {
    // User details such as address, etc.
    type: mongoose.Schema.Types.Mixed,
    default: () => ({}),
  },
  settings: {
    // User settings such as verification status, etc.
    type: mongoose.Schema.Types.Mixed,
    default: {},
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
});

userSchema.pre('save', async function () {
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});

// Instance method to create JWT
userSchema.methods.createJWT = function () {
  return jwt.sign(
    { userId: this._id, name: this.name },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_LIFETIME },
  );
};

// Check if the password is correct
userSchema.methods.comparePassword = async function (entryPassword) {
  const isMatch = await bcrypt.compare(entryPassword, this.password);
  return isMatch;
};

// Check if the password was changed after the JWT was issued
userSchema.methods.changedPasswordAfter = function (JWTTimestamp) {
  if (this.passwordChangedAt) {
    const changedTimestamp = parseInt(
      this.passwordChangedAt.getTime() / 1000,
      10,
    );
    return JWTTimestamp < changedTimestamp;
  }

  // False means the password has NOT been changed
  return false;
};

// Generate password reset token
userSchema.methods.createPasswordResetToken = function () {
  const resetToken = crypto.randomBytes(3).toString('hex');

  this.passwordResetToken = crypto
    .createHash('sha256')
    .update(resetToken)
    .digest('hex');

  this.passwordResetExpires = Date.now() + 10 * 60 * 1000; // 10 minutes

  return resetToken;
};

// Pre-save middleware to hash the password if it's modified
userSchema.pre('save', async function (next) {
  // Only run this function if password was actually modified or the document is new
  if (!this.isModified('password')) return next();

  // Hash the password with cost of 12
  this.password = await bcrypt.hash(this.password, 12);

  // Delete confirmPassword field after validation
  this.confirmPassword = undefined;

  next();
});

// Pre-save middleware to set passwordChangedAt for new passwords
userSchema.pre('save', function (next) {
  // Only set passwordChangedAt if the password was modified and the document is not new
  if (!this.isModified('password') || this.isNew) return next();

  this.passwordChangedAt = Date.now() - 1000; // Set to just before token is issued
  next();
});

// Pre-query middleware to exclude inactive users
userSchema.pre(/^find/, function (next) {
  this.find({ active: { $ne: false } });
  next();
});

// Generate email verification code
userSchema.methods.createVerificationCode = function () {
  const verificationCode = crypto.randomBytes(3).toString('hex');

  this.verificationCode = crypto
    .createHash('sha256')
    .update(verificationCode)
    .digest('hex');

  this.codeExpires = Date.now() + 10 * 60 * 1000; // 10 minutes

  return verificationCode;
};

const User = mongoose.model('User', userSchema);

module.exports = User;
