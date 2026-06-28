const mongoose = require('mongoose');

const budgetSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    monthly_limit: { type: Number, required: true },
    month: { type: Number, required: true },
    year: { type: Number, required: true }
});
module.exports = mongoose.model('Budget', budgetSchema);