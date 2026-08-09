const Transaction = require('../models/Transaction');
const User = require('../models/User');
const { getExpenseInsight, autoClassifyTransaction, askFinancialAssistant, extractExpenseDetails } = require('../services/aiService');

// 1. Generate Full Report/Insight
exports.generateInsight = async (req, res) => {
    try {
        const userId = req.user.id;
        const transactions = await Transaction.find({ userId }).sort({ date: -1 }).limit(50);
        const user = await User.findById(userId);

        const profile = { currency: user.currency, savingsGoal: user.savingsGoal };
        const insight = await getExpenseInsight(transactions, profile);

        res.status(200).json({ success: true, insight });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// 2. Classify Single Transaction (for description field typing)
exports.classifyTransaction = async (req, res) => {
    try {
        const { description } = req.body;
        const category = await autoClassifyTransaction(description);
        res.status(200).json({ success: true, category });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// 3. Interactive AI Chat Q&A
exports.chatWithAI = async (req, res) => {
    try {
        const { query } = req.body;
        const userId = req.user.id;

        const transactions = await Transaction.find({ userId });
        
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
            expenses: transactions.filter(t => t.type === 'Expense').slice(0, 10).map(t => ({ item: t.description || t.category, amount: t.amount }))
        };

        const answer = await askFinancialAssistant(query, contextData);
        res.status(200).json({ success: true, answer });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// 4. Smart Auto-fill (Extract text to form data)
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

// 5. Get Previous AI Reports
exports.getReports = async (req, res) => {
    try {
        // Currently returns an empty array to resolve frontend calls without errors
        res.status(200).json([]);
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};