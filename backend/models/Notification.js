const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    title: String,
    message: String,
    status: { type: String, default: 'unread' },
    created_at: { type: Date, default: Date.now }
});
module.exports = mongoose.model('Notification', notificationSchema);