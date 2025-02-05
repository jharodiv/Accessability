const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

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
    type: new mongoose.Schema({
      address: {
        type: String,
        default: null,
      },
      phoneNumber: {
        type: String,
        default: null,
      },
      profilePicture: {
        type: String,
        default:
          'https://res.cloudinary.com/dfenjj2vs/image/upload/v1738594296/1ffe033b103737d30ee1c98c1d9c51a6_nv95n5.png',
      },
    }),
    default: () => ({}),
  },
  settings: {
    type: new mongoose.Schema({
      verificationCode: {
        type: String,
        default: null,
      },
      codeExpiresAt: {
        type: Date,
        default: null,
      },
      verified: {
        type: Boolean,
        default: false,
      },
      passwordChangedAt: {
        type: Date,
        default: null,
      },
      passwordResetToken: {
        type: String,
        default: null,
      },
      passwordResetExpiresAt: {
        type: Date,
        default: null,
      },
      active: {
        type: Boolean,
        default: true,
      },
    }),
    default: () => ({}),
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

// Pre-save middleware to hash the password if it's modified
userSchema.pre('save', async function (next) {
  // Only run this function if password was actually modified or the document is new
  if (!this.isModified('password')) return next();

  // Hash the password with a cost of 12
  this.password = await bcrypt.hash(this.password, 12);

  // Delete confirmPassword field if it exists (if you use it for validation)
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

// Generate email verification code
userSchema.methods.createVerificationCode = function () {
  const verificationCode = crypto.randomBytes(3).toString('hex');

  this.settings.verificationCode = crypto
    .createHash('sha256')
    .update(verificationCode)
    .digest('hex');

  this.settings.codeExpiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

  return verificationCode;
};

const User = mongoose.model('User', userSchema);

module.exports = User;
