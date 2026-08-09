// backend/controllers/aiReportController.js

const AiReport = require('../models/AiReport');
const { getExpenseInsight, autoClassifyTransaction } = require('../services/aiService');
const Transaction = require('../models/Transaction');
const User = require('../models/User');

exports.getReports = async (req, res) => {
    try {
        const reports = await AiReport.find({ userId: req.user.id }).sort({ generated_at: -1 });
        res.status(200).json(reports);
    } catch (error) {
        res.status(500).json({ message: "Error fetching AI reports" });
    }
};

exports.generateInsight = async (req, res) => {
    try {
        const transactions = await Transaction.find({ userId: req.user.id });
        
        if (transactions.length === 0) {
            return res.status(400).json({ message: "No transactions found. Please add some transactions first." });
        }

        // Fetch User Profile to get savings goal and currency (FR-06)
        const userProfile = await User.findById(req.user.id);

        const insightText = await getExpenseInsight(transactions, userProfile);

        const report = await AiReport.create({
            userId: req.user.id,
            insight_text: insightText
        });

        res.status(201).json({ message: "Insight generated successfully", report });
    } catch (error) {
        res.status(500).json({ message: error.message || "Failed to generate insight" });
    }
};

exports.getForecasts = async (req, res) => {
    try {
        const reports = await AiReport.find({ userId: req.user.id })
            .sort({ generated_at: -1 });
        
        if (reports.length === 0) {
            return res.status(200).json({ 
                message: "No forecasts found. Please generate a new AI report." 
            });
        }
        
        res.status(200).json(reports);
    } catch (error) {
        console.error('Get Forecasts Error:', error.message);
        res.status(500).json({ 
            message: "Error fetching forecasts", 
            error: error.message 
        });
    }
};

// New Controller for Automated Classification (FR-04)
exports.classifyTransaction = async (req, res) => {
    try {
        const { description } = req.body;
        if (!description) return res.status(400).json({ category: "Other" });
        
        const category = await autoClassifyTransaction(description);
        res.status(200).json({ category });
    } catch (error) {
        console.error('Classification Error:', error.message);
        res.status(500).json({ category: "Other" });
    }
};