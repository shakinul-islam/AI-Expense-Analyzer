const User = require('../models/User');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { sendResetEmail } = require('../services/emailService');

exports.registerUser = async (req, res) => {
    try {
        const { name, email, password } = req.body;
        const userExists = await User.findOne({ email });
        if (userExists) return res.status(400).json({ message: "User already exists" });

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);
        await User.create({ name, email, password: hashedPassword });
        res.status(201).json({ message: "User registered successfully" });
    } catch (error) {
        res.status(500).json({ message: "Server error" });
    }
};

exports.loginUser = async (req, res) => {
    try {
        const { email, password } = req.body;
        const user = await User.findOne({ email });
        if (!user) return res.status(400).json({ message: "Invalid credentials" });

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) return res.status(400).json({ message: "Invalid credentials" });

        const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '7d' });
        res.status(200).json({
            token,
            user: { name: user.name, email: user.email, currency: user.currency }
        });
    } catch (error) {
        res.status(500).json({ message: "Server error" });
    }
};

// ==========================================
// 🚀 FORGOT PASSWORD (Generate & Auto-fill OTP)
// ==========================================
exports.forgotPassword = async (req, res) => {
    try {
        const { email } = req.body;
        if (!email) return res.status(400).json({ message: "Email is required" });

        const user = await User.findOne({ email: email.toLowerCase() });
        if (!user) {
            return res.status(200).json({
                message: "If an account exists with that email, an OTP has been sent."
            });
        }

        // Generate 6-digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        
        // Hash the OTP before saving for security
        const hashedOTP = crypto.createHash('sha256').update(otp).digest('hex');

        user.resetPasswordOTP = hashedOTP;
        user.resetPasswordExpires = Date.now() + 10 * 60 * 1000; // 10 minutes
        await user.save();

        try {
            await sendResetEmail(user.email, otp);
        } catch (mailErr) {
            console.error('Email send error:', mailErr.message);
            user.resetPasswordOTP = null;
            user.resetPasswordExpires = null;
            await user.save();
            return res.status(500).json({ message: "Could not send OTP. Try again." });
        }

        // 🚀 DEV MODE: Send OTP in response so frontend can auto-fill
        res.status(200).json({
            message: "If an account exists with that email, an OTP has been sent.",
            devOtp: otp // Frontend will use this for auto-fill
        });
    } catch (error) {
        console.error('Forgot Password Error:', error.message);
        res.status(500).json({ message: "Server error" });
    }
};

// ==========================================
// 🚀 RESET PASSWORD (Verify OTP)
// ==========================================
exports.resetPassword = async (req, res) => {
    try {
        const { email, otp, newPassword } = req.body;

        if (!email || !otp || !newPassword) {
            return res.status(400).json({ message: "Email, OTP, and new password are required" });
        }
        if (newPassword.length < 6) {
            return res.status(400).json({ message: "Password must be at least 6 characters" });
        }

        const hashedOTP = crypto.createHash('sha256').update(otp).digest('hex');

        const user = await User.findOne({
            email: email.toLowerCase(),
            resetPasswordOTP: hashedOTP,
            resetPasswordExpires: { $gt: Date.now() }
        });

        if (!user) {
            return res.status(400).json({ message: "Invalid or expired OTP" });
        }

        const salt = await bcrypt.genSalt(10);
        user.password = await bcrypt.hash(newPassword, salt);
        user.resetPasswordOTP = null;
        user.resetPasswordExpires = null;
        await user.save();

        res.status(200).json({ message: "Password reset successfully. You can now login." });
    } catch (error) {
        console.error('Reset Password Error:', error.message);
        res.status(500).json({ message: "Server error" });
    }
};