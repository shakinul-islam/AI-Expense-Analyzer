const AiReport = require('../models/AiReport');
const { getExpenseInsight } = require('../services/aiService'); // নিশ্চিত করুন এই ফাইলে Groq এর কোড আছে
const Transaction = require('../models/Transaction');

// ১. রিপোর্ট দেখার জন্য
exports.getReports = async (req, res) => {
    try {
        const reports = await AiReport.find({ userId: req.user.id }).sort({ generated_at: -1 });
        res.status(200).json(reports);
    } catch (error) {
        res.status(500).json({ message: "Error fetching AI reports" });
    }
};

// ২. রিপোর্ট বা ফোরকাস্ট জেনারেট করার জন্য
exports.generateInsight = async (req, res) => {
    try {
        const transactions = await Transaction.find({ userId: req.user.id });
        if (transactions.length === 0) {
            return res.status(400).json({ message: "No transactions found" });
        }

        const insightText = await getExpenseInsight(transactions);

        const report = await AiReport.create({
            userId: req.user.id,
            insight_text: insightText
            // আপনার মডেলে যদি generated_at বা createdAt থাকে, তবে সেটি অটোমেটিক সেট হবে
        });

        res.status(201).json({ message: "Insight generated", report });
    } catch (error) {
        console.error("DEBUG ERROR:", error);
        res.status(500).json({ message: error.message || "Unknown error" });
    }
};

// ৩. ফোরকাস্টের জন্য (এটিকে আলাদা রাউটে কল করুন)
exports.getForecasts = async (req, res) => {
    try {
        // এখানে Forecast এর পরিবর্তে AiReport মডেলটি ব্যবহার করুন
        const reports = await AiReport.find({ userId: req.user.id }).sort({ generated_at: -1 });
        
        if (reports.length === 0) {
            return res.status(200).json({ message: "No forecasts found. Please generate a new AI report." });
        }
        
        res.status(200).json(reports);
    } catch (error) {
        res.status(500).json({ message: "Error fetching forecasts", error: error.message });
    }
};