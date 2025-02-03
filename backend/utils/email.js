const nodemailer = require('nodemailer');

//!GMAIL;
const sendEmail = async (options) => {
  // ** 1.) Create a Transporter
  const transporter = nodemailer.createTransport({
    service: 'gmail',
    host: 'smtp.gmail.com',
    port: 587,
    auth: {
      user: process.env.USER_EMAIL,
      pass: process.env.USER_PASSWORD,
    },
  });

  // Email Verification Template
  if (options.type === 'verification') {
    const message = `
      <div style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f4f4f4;">
        <table style="border: 2px solid #6750A4; border-radius: 5px; padding: 10px; max-width: 600px; margin: auto; border-collapse: collapse; background-color: #ffffff;">
          <tr>
            <td style="padding: 10px; text-align: center;">
              <h2 style="color: #6750A4;">Email Verification</h2>
              <p style="font-size: 16px;">Your verification code is:</p>
              <strong style="font-size: 20px; display: inline-block; padding: 10px; border: 2px solid #6750A4; border-radius: 5px;">${options.verificationCode}</strong>
              <br>
              <p>This code is valid for 10 minutes.</p>
            </td>
          </tr>
        </table>
      </div>`;

    // ** 2.) Define the email options for verification
    const mailOptions = {
      from: 'accessability16@gmail.com>',
      to: options.email,
      subject: options.subject,
      text: options.message,
      html: message,
    };

    // ** 3.) Actually send the email for verification
    await transporter.sendMail(mailOptions);
  }

  // Password Reset Email Template
  else if (options.type === 'reset') {
    const message = `
      <div style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f4f4f4;">
        <table style="border: 2px solid #6750A4; border-radius: 5px; padding: 10px; max-width: 600px; margin: auto; border-collapse: collapse; background-color: #ffffff;">
          <tr>
            <td style="padding: 10px; text-align: center;">
              <h2 style="color: #6750A4;">Password Reset</h2>
              <p style="font-size: 16px;">If you forgot your password, paste this code:</p>
              <strong style="font-size: 20px; display: inline-block; padding: 10px; border: 2px solid #6750A4; border-radius: 5px;">${options.resetToken}</strong>
              <br>
              <p>If you didn't forget your password, please ignore this email!</p>
            </td>
          </tr>
        </table>
      </div>`;

    // ** 2.) Define the email options for password reset
    const mailOptions = {
      from: 'accessability16@gmail.com>',
      to: options.email,
      subject: options.subject,
      text: options.message,
      html: message,
    };

    // ** 3.) Actually send the email for password reset
    await transporter.sendMail(mailOptions);
  }
};

module.exports = sendEmail;
