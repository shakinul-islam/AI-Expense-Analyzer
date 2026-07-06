const User = require('../models/User');

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
        const { full_name, currency, savings_goal } = req.body;
        
        const updateData = {};
        if (full_name) updateData.name = full_name;
        if (currency) updateData.currency = currency;
        if (savings_goal !== undefined) updateData.savingsGoal = savings_goal;
        
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