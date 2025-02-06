// const jwt = require('jsonwebtoken');
// const User = require('../models/User');
// const catchAsync = require('../utils/catchAsync');
// const AppError = require('../utils/appError');

// exports.protect = catchAsync(async (req, res, next) => {
//   //! 1) Getting token and check of it's there
//   let token;
//   if (
//     req.headers.authorization &&
//     req.headers.authorization.startsWith('Bearer')
//   ) {
//     token = req.headers.authorization.split(' ')[1];
//   }
//   if (!token) {
//     return next(
//       new AppError(
//         'You are not logged in!, Please login in to get access',
//         401,
//       ),
//     );
//   }
//   //! 2) Verification token
//   const decoded = await promisify(jwt.verify)(token, process.env.JWT_SECRET);
//   //! 3) Check if user still exists
//   const currentUser = await User.findById(decoded.id);
//   if (!currentUser) {
//     return next(
//       new AppError(
//         'The token belonging to this user is no longer exists.',
//         401,
//       ),
//     );
//   }

//   //! 4) Check if user changed password after the JWT was issued
//   if (currentUser.changedPasswordAfter(decoded.iat)) {
//     return next(
//       new AppError('User recently changed password!, Please login again', 401),
//     );
//   }

//   // !! GRANT ACCESS TO THE USER ROUTE
//   req.user = currentUser;
//   next();
// });
