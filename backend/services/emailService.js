const nodemailer = require('nodemailer');

/**
 * Sends a password reset email.
 * Configure SMTP credentials in .env:
 *   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM, APP_URL
 * If not configured, logs the reset link to console (dev mode).
 */
const sendResetEmail = async (email, resetToken) => {
    const appUrl = process.env.APP_URL || 'http://localhost:5000';
    const resetLink = `${appUrl}/reset-password?token=${resetToken}`;

    // If SMTP not configured, fallback to console log (dev)
    if (!process.env.SMTP_HOST || !process.env.SMTP_USER) {
        console.log('═══════════════════════════════════════════════');
        console.log('📧 PASSWORD RESET EMAIL (DEV MODE - no SMTP)');
        console.log('To:      ', email);
        console.log('Subject: Reset your AI Expense Analyzer password');
        console.log('Link:    ', resetLink);
        console.log('Token:   ', resetToken);
        console.log('Expires:  in 1 hour');
        console.log('═══════════════════════════════════════════════');
        return { dev: true, resetLink };
    }

    const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: parseInt(process.env.SMTP_PORT || '587'),
        secure: process.env.SMTP_SECURE === 'true',
        auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS
        }
    });

    const mailOptions = {
        from: process.env.SMTP_FROM || process.env.SMTP_USER,
        to: email,
        subject: 'Reset your AI Expense Analyzer password',
        html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
                <h2 style="color: #4F46E5;">Password Reset Request</h2>
                <p>You requested to reset your password for AI Expense Analyzer.</p>
                <p>Click the button below to reset your password. This link expires in <b>1 hour</b>.</p>
                <p style="margin: 30px 0;">
                    <a href="${resetLink}"
                       style="background: #4F46E5; color: white; padding: 12px 28px;
                              text-decoration: none; border-radius: 8px; font-weight: bold;">
                        Reset Password
                    </a>
                </p>
                <p style="color: #666; font-size: 12px;">
                    If you didn't request this, ignore this email. Your password won't change.
                </p>
                <p style="color: #999; font-size: 11px;">
                    Or copy this link: ${resetLink}
                </p>
            </div>
        `
    };

    await transporter.sendMail(mailOptions);
    return { dev: false };
};

module.exports = { sendResetEmail };