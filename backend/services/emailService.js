const nodemailer = require('nodemailer');

const sendResetEmail = async (email, otp) => {
    // If SMTP not configured, fallback to console log (dev mode)
    if (!process.env.SMTP_HOST || !process.env.SMTP_USER) {
        console.log('═══════════════════════════════════════════════');
        console.log('📧 PASSWORD RESET OTP (DEV MODE - no SMTP)');
        console.log('To:      ', email);
        console.log('OTP:     ', otp);
        console.log('Expires:  in 10 minutes');
        console.log('═══════════════════════════════════════════════');
        return { dev: true, otp };
    }

    const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: parseInt(process.env.SMTP_PORT || '587'),
        secure: process.env.SMTP_SECURE === 'true',
        auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
    });

    const mailOptions = {
        from: process.env.SMTP_FROM || process.env.SMTP_USER,
        to: email,
        subject: 'Your Password Reset OTP - AI Expense Analyzer',
        html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
                <h2 style="color: #4F46E5;">Password Reset OTP</h2>
                <p>You requested to reset your password for AI Expense Analyzer.</p>
                <p>Use the following One-Time Password (OTP) to reset your password:</p>
                <div style="background: #F3F4F6; padding: 20px; text-align: center; border-radius: 10px; margin: 20px 0;">
                    <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #4F46E5;">${otp}</span>
                </div>
                <p style="color: #666; font-size: 14px;">This OTP will expire in <b>10 minutes</b>.</p>
                <p style="color: #999; font-size: 12px;">If you didn't request this, ignore this email. Your password won't change.</p>
            </div>
        `
    };

    await transporter.sendMail(mailOptions);
    return { dev: false };
};

module.exports = { sendResetEmail };