const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
  },
  password: {
    type: String,
    required: true,
  },
  role: {
    type: String,
    enum: ['PWD', 'Caregiver'],
    required: true,
  },
  accessibilityProfile: {
    mobilityType: {
      type: String,
      enum: ['Wheelchair', 'Visually Impaired', 'Other'],
    },
    customSettings: {
      type: [String],
    },
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

userSchema.methods.createJWT = function () {
  return jwt.sign(
    { userId: this._id, name: this.name },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_LIFETIME },
  );
};

userSchema.methods.comparePassword = async function (entryPassword) {
  const isMatch = await bcrypt.compare(entryPassword, this.password);
  return isMatch;
};

const User = mongoose.model('User', userSchema);

module.exports = User;
