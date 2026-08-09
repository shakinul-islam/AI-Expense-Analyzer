const Notification = require('../models/Notification');

exports.getNotifications = async (req, res) => {
    try {
        const notifications = await Notification.find({ userId: req.user.id })
            .sort({ created_at: -1 });
        res.status(200).json(notifications);
    } catch (error) {
        console.error('Get Notifications Error:', error.message);
        res.status(500).json({ message: "Error fetching notifications" });
    }
};

exports.markAsRead = async (req, res) => {
    try {
        const notification = await Notification.findByIdAndUpdate(
            req.params.id, 
            { status: 'read' },
            { new: true }
        );
        
        if (!notification) {
            return res.status(404).json({ message: "Notification not found" });
        }
        
        res.status(200).json({ message: "Marked as read", notification });
    } catch (error) {
        console.error('Mark as Read Error:', error.message);
        res.status(500).json({ message: "Error updating notification" });
    }
};

// 🚀 New: Delete Notification
exports.deleteNotification = async (req, res) => {
    try {
        const notificationId = req.params.id;
        const userId = req.user.id;

        const notification = await Notification.findOne({ _id: notificationId, userId: userId });

        if (!notification) {
            return res.status(404).json({ message: "Notification not found or unauthorized" });
        }

        await Notification.findByIdAndDelete(notificationId);

        res.status(200).json({ message: "Notification deleted successfully" });
    } catch (error) {
        console.error('Delete Notification Error:', error.message);
        res.status(500).json({ message: "Error deleting notification" });
    }
};