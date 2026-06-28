const mongoose = require('mongoose');

const forecastSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    predicted_amount: { type: Number, required: true },
    prediction_month: { type: Number, required: true },
    year: { type: Number, required: true }
});
module.exports = mongoose.model('Forecast', forecastSchema);