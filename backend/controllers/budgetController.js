const Budget = require('../models/Budget');

exports.setBudget = async (req, res) => {
    try {
        const { monthly_limit, month, year } = req.body;
        const budget = await Budget.create({ userId: req.user.id, monthly_limit, month, year });
        res.status(201).json(budget);
    } catch (error) {
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