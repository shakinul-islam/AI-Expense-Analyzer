const User = require('../models/User');
const Transaction = require('../models/Transaction');
const Budget = require('../models/Budget');
const Notification = require('../models/Notification');

exports.getProfile = async (req, res) => {
    try {
        const user = await User.findById(req.user.id).select('-password');
        if (!user) {
            return res.status(404).json({ message: "User not found" });
        }
        res.status(200).json(user);
    } catch (error) {
        console.error('Get Profile Error:', error.message);
        res.status(500).json({ message: "Error fetching profile" });
    }
};

exports.updateProfile = async (req, res) => {
    try {
        const { full_name, currency, savings_goal, profile_picture } = req.body;
        
        const updateData = {};
        if (full_name) updateData.name = full_name;
        if (currency) updateData.currency = currency;
        if (savings_goal !== undefined) updateData.savingsGoal = savings_goal;
        if (profile_picture !== undefined) updateData.profilePicture = profile_picture;
        
        const updatedUser = await User.findByIdAndUpdate(
            req.user.id,
            updateData,
            { new: true, runValidators: true }
        ).select('-password');

        if (!updatedUser) {
            return res.status(404).json({ message: "User not found" });
        }

        res.status(200).json({ 
            message: "Profile updated successfully", 
            user: updatedUser 
        });
    } catch (error) {
        console.error('Update Profile Error:', error.message);
        res.status(500).json({ message: "Error updating profile" });
    }
};

// 🚀 NEW: Delete Account (Cascade Delete)
exports.deleteAccount = async (req, res) => {
    try {
        const userId = req.user.id;

        // Delete all related data
        await Transaction.deleteMany({ userId });
        await Budget.deleteMany({ userId });
        await Notification.deleteMany({ userId });
        
        // Delete the user
        const user = await User.findByIdAndDelete(userId);
        
        if (!user) {
            return res.status(404).json({ message: "User not found" });
        }

        res.status(200).json({ message: "Account deleted successfully" });
    } catch (error) {
        console.error('Delete Account Error:', error.message);
        res.status(500).json({ message: "Server error while deleting account" });
    }
};

// ==========================================
// 🚀 Custom Category Management
// ==========================================

const DEFAULT_CATEGORIES = [
    'Food', 'Transport', 'Shopping', 'Entertainment',
    'Bills', 'Health', 'Education', 'Salary', 'Investment', 'Other'
];

exports.addCustomCategory = async (req, res) => {
    try {
        const { category } = req.body;

        if (!category || category.trim().length === 0) {
            return res.status(400).json({ message: "Category name is required" });
        }

        const trimmed = category.trim();

        if (trimmed.length > 30) {
            return res.status(400).json({ message: "Category name too long (max 30 chars)" });
        }

        const user = await User.findById(req.user.id);
        if (!user) return res.status(404).json({ message: "User not found" });

        const allNames = [
            ...DEFAULT_CATEGORIES.map(c => c.toLowerCase()),
            ...user.customCategories.map(c => c.toLowerCase())
        ];

        if (allNames.includes(trimmed.toLowerCase())) {
            return res.status(400).json({ message: "Category already exists" });
        }

        user.customCategories.push(trimmed);
        await user.save();

        res.status(201).json({
            message: "Category added successfully",
            customCategories: user.customCategories
        });
    } catch (error) {
        console.error('Add Category Error:', error.message);
        res.status(500).json({ message: "Error adding category" });
    }
};

exports.deleteCustomCategory = async (req, res) => {
    try {
        const { category } = req.params;
        const decoded = decodeURIComponent(category);

        const user = await User.findById(req.user.id);
        if (!user) return res.status(404).json({ message: "User not found" });

        if (DEFAULT_CATEGORIES.map(c => c.toLowerCase()).includes(decoded.toLowerCase())) {
            return res.status(400).json({ message: "Cannot delete default category" });
        }

        user.customCategories = user.customCategories.filter(
            c => c.toLowerCase() !== decoded.toLowerCase()
        );
        await user.save();

        res.status(200).json({
            message: "Category deleted",
            customCategories: user.customCategories
        });
    } catch (error) {
        console.error('Delete Category Error:', error.message);
        res.status(500).json({ message: "Error deleting category" });
    }
};

exports.getCustomCategories = async (req, res) => {
    try {
        const user = await User.findById(req.user.id).select('customCategories');
        if (!user) return res.status(404).json({ message: "User not found" });

        res.status(200).json({
            customCategories: user.customCategories || []
        });
    } catch (error) {
        console.error('Get Categories Error:', error.message);
        res.status(500).json({ message: "Error fetching categories" });
    }
};