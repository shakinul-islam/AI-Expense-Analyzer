const Budget = require('../models/Budget');

// 🚀 BUG FIX: Use upsert so we update existing budget instead of creating duplicates
exports.setBudget = async (req, res) => {
    try {
        const { monthly_limit, month, year } = req.body;
        const userId = req.user.id;

        if (monthly_limit === undefined || !month || !year) {
            return res.status(400).json({ message: "monthly_limit, month, year are required" });
        }

        // Use findOneAndUpdate with upsert to prevent duplicate budgets
        const budget = await Budget.findOneAndUpdate(
            { userId, month, year },
            { monthly_limit },
            { new: true, upsert: true, setDefaultsOnInsert: true }
        );

        res.status(200).json(budget);
    } catch (error) {
        console.error('Set Budget Error:', error.message);
        res.status(500).json({ message: "Error setting budget" });
    }
};

exports.getBudgets = async (req, res) => {
    try {
        const budgets = await Budget.find({ userId: req.user.id });
        res.status(200).json(budgets);
    } catch (error) {
        res.status(500).json({ message: "Error fetching budgets" });
    }
};

exports.deleteBudget = async (req, res) => {
    try {
        const { month, year } = req.params;
        const result = await Budget.findOneAndDelete({
            userId: req.user.id,
            month: Number(month),
            year: Number(year)
        });
        if (!result) {
            return res.status(404).json({ message: "Budget not found" });
        }
        res.status(200).json({ message: "Budget removed" });
    } catch (error) {
        res.status(500).json({ message: "Error deleting budget" });
    }
};