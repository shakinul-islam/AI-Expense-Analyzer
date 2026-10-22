const Transaction = require('../models/Transaction');
const User = require('../models/User');
const AiReport = require('../models/AiReport');
const {
    getExpenseInsight,
    autoClassifyTransaction,
    askFinancialAssistant,
    extractExpenseDetails
} = require('../services/aiService');

// 1. Generate + SAVE insight report
exports.generateInsight = async (req, res) => {
    try {
        const userId = req.user.id;
        const transactions = await Transaction.find({ userId }).sort({ date: -1 }).limit(50);
        const user = await User.findById(userId);

        if (transactions.length === 0) {
            return res.status(400).json({
                success: false,
                message: "No transactions found. Add some first."
            });
        }

        const profile = { currency: user.currency, savingsGoal: user.savingsGoal };
        const insight = await getExpenseInsight(transactions, profile);

        // 🚀 FIX: persist the report so /reports returns it later
        const report = await AiReport.create({
            userId,
            insight_text: insight
        });

        res.status(201).json({ success: true, insight, reportId: report._id });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// 2. Classify single transaction
exports.classifyTransaction = async (req, res) => {
    try {
        const { description } = req.body;
        if (!description) return res.status(400).json({ category: "Other" });
        const category = await autoClassifyTransaction(description);
        res.status(200).json({ success: true, category });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// 3. Chat
exports.chatWithAI = async (req, res) => {
    try {
        const { query } = req.body;
        const userId = req.user.id;

        const transactions = await Transaction.find({ userId }).limit(200);

        let income = 0;
        let totalSpent = 0;

        transactions.forEach(t => {
            if (t.type === 'Income') income += t.amount;
            else totalSpent += t.amount;
        });

        const contextData = {
            income,
            totalSpent,
            remaining: income - totalSpent,
            expenses: transactions
                .filter(t => t.type === 'Expense')
                .slice(0, 10)
                .map(t => ({ item: t.description || t.category, amount: t.amount }))
        };

        const answer = await askFinancialAssistant(query, contextData);
        res.status(200).json({ success: true, answer });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// 4. Smart auto-fill
exports.extractExpense = async (req, res) => {
    try {
        const { text } = req.body;
        const extractedData = await extractExpenseDetails(text);
        if (extractedData) {
            res.status(200).json({ success: true, data: extractedData });
        } else {
            res.status(400).json({ success: false, message: "Could not extract data" });
        }
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// 🚀 FIX: Return actual saved reports
exports.getReports = async (req, res) => {
    try {
        const reports = await AiReport.find({ userId: req.user.id })
            .sort({ generated_at: -1 })
            .limit(30);
        res.status(200).json(reports);
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// 🚀 NEW: Delete an AI report
exports.deleteReport = async (req, res) => {
    try {
        const report = await AiReport.findOneAndDelete({
            _id: req.params.id,
            userId: req.user.id
        });
        if (!report) return res.status(404).json({ message: "Report not found" });
        res.status(200).json({ message: "Report deleted" });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};