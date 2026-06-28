const User = require('../models/User');


exports.getProfile = async (req, res) => {
    try {
       
        const user = await User.findById(req.user.id).select('-password_hash'); 
        if (!user) return res.status(404).json({ message: "User not found" });
        
        res.status(200).json(user);
    } catch (error) {
        res.status(500).json({ message: "Error fetching profile" });
    }
};


exports.updateProfile = async (req, res) => {
    try {
        const { full_name, currency, savings_goal } = req.body;
        
        const updatedUser = await User.findByIdAndUpdate(
            req.user.id,
            { full_name, currency, savings_goal },
            { new: true } 
        ).select('-password_hash');

        res.status(200).json({ message: "Profile updated successfully", updatedUser });
    } catch (error) {
        res.status(500).json({ message: "Error updating profile" });
    }
};