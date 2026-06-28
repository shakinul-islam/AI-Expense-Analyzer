const mongoose = require('mongoose');

const aiReportSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    insight_text: { type: String, required: true },
    generated_at: { type: Date, default: Date.now }
});
module.exports = mongoose.model('AiReport', aiReportSchema);