const Forecast = require('../models/Forecast');

exports.getForecasts = async (req, res) => {
    try {
        const forecasts = await Forecast.find({ userId: req.user.id }).sort({ createdAt: -1 });
        
        if (forecasts.length === 0) {
            return res.status(200).json({ message: "No forecasts found. Please generate a new AI report." });
        }
        
        res.status(200).json(forecasts);
    } catch (error) {
        res.status(500).json({ message: "Error fetching forecasts", error: error.message });
    }
};