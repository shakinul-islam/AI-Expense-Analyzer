const Transaction = require('../models/Transaction');
const Budget = require('../models/Budget');
const Notification = require('../models/Notification');
const mongoose = require('mongoose');

exports.addTransaction = async (req, res) => {
    try {
        const { amount, category, description, type } = req.body;
        const userId = req.user.id;

        // Validate
        if (!amount || !category || !type) {
            return res.status(400).json({ 
                message: "Amount, category, and type are required" 
            });
        }

        if (!['Income', 'Expense'].includes(type)) {
            return res.status(400).json({ 
                message: "Type must be 'Income' or 'Expense'" 
            });
        }

        const newTransaction = await Transaction.create({ 
            userId, 
            amount, 
            category, 
            description, 
            type 
        });

        // Check budget
        const budget = await Budget.findOne({ userId }).sort({ createdAt: -1 });

        if (budget && type === 'Expense') {
            const totalSpent = await Transaction.aggregate([
                { $match: { 
                    userId: new mongoose.Types.ObjectId(userId),
                    type: 'Expense'
                }},
                { $group: { _id: null, total: { $sum: "$amount" } } }
            ]);

            const currentTotal = totalSpent[0]?.total || 0;

            if (currentTotal > budget.monthly_limit) {
                await Notification.create({
                    userId,
                    title: "Budget Alert!",
                    message: `⚠️ Your spending (${currentTotal}) has exceeded your budget limit (${budget.monthly_limit}).`,
                    status: 'unread'
                });
            }
        }

        res.status(201).json(newTransaction);
    } catch (error) {
        console.error('Add Transaction Error:', error.message);
        res.status(500).json({ message: error.message });
    }
};

exports.getTransactions = async (req, res) => {
    try {
        const transactions = await Transaction.find({ userId: req.user.id })
            .sort({ date: -1 });
        res.status(200).json(transactions);
    } catch (error) {
        console.error('Get Transactions Error:', error.message);
        res.status(500).json({ message: "Server error during fetching transactions" });
    }
};

exports.getSummary = async (req, res) => {
    try {
        const userId = req.user.id;

        const summary = await Transaction.aggregate([
            { $match: { userId: new mongoose.Types.ObjectId(userId) } },
            { 
                $group: { 
                    _id: "$category", 
                    totalAmount: { $sum: "$amount" },
                    count: { $sum: 1 },
                    income: { 
                        $sum: { 
                            $cond: [{ $eq: ["$type", "Income"] }, "$amount", 0] 
                        } 
                    },
                    expense: { 
                        $sum: { 
                            $cond: [{ $eq: ["$type", "Expense"] }, "$amount", 0] 
                        } 
                    }
                } 
            },
            { $sort: { totalAmount: -1 } }
        ]);

        res.status(200).json({
            success: true,
            data: summary
        });
    } catch (error) {
        console.error('Get Summary Error:', error.message);
        res.status(500).json({ 
            success: false, 
            message: "Summary generation failed", 
            error: error.message 
        });
    }
};