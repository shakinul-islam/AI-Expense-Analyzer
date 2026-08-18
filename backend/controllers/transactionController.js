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

        // ==========================================
        // 🚀 DYNAMIC BUDGET ALERT LOGIC (100% FIXED)
        // ==========================================
        if (type === 'Expense') {
            const currentDate = new Date();
            const currentMonth = currentDate.getMonth() + 1; // 1-12
            const currentYear = currentDate.getFullYear();

            // 🛠️ BULLETPROOF BUG FIX: ALWAYS force MongoDB to return the ABSOLUTE LATEST updated/created budget for this month
            let budget = await Budget.findOne({ 
                userId, 
                month: currentMonth, 
                year: currentYear 
            }).sort({ updatedAt: -1, _id: -1 });
            
            if (!budget) {
                // Global fallback: get the most recently EDITED budget overall
                budget = await Budget.findOne({ userId }).sort({ updatedAt: -1, _id: -1 });
            }

            // Ensure budget exists and is greater than 0
            if (budget && budget.monthly_limit > 0) {
                const startOfMonth = new Date(currentYear, currentMonth - 1, 1);
                const endOfMonth = new Date(currentYear, currentMonth, 0, 23, 59, 59);
                const budgetLimit = budget.monthly_limit; // Now it will correctly be 4400

                // Calculate total spent THIS month (includes the transaction just added)
                const totalSpentAgg = await Transaction.aggregate([
                    { $match: { 
                        userId: new mongoose.Types.ObjectId(userId),
                        type: 'Expense',
                        date: { $gte: startOfMonth, $lte: endOfMonth }
                    }},
                    { $group: { _id: null, total: { $sum: "$amount" } } }
                ]);

                const currentTotal = totalSpentAgg[0]?.total || 0;
                
                // Calculate percentages and remaining amount dynamically
                const spentPercentage = currentTotal / budgetLimit;
                const spentPercentageDisplay = Math.round(spentPercentage * 100);
                const remainingAmount = budgetLimit - currentTotal;

                // 1. Budget Exceeded Alert (100% or more)
                if (spentPercentage >= 1.0) {
                    await Notification.create({
                        userId,
                        title: "🚨 Budget Exceeded!",
                        message: `You have crossed your budget limit! You spent ${spentPercentageDisplay}% of your ৳${budgetLimit} budget. Total spent: ৳${currentTotal}.`,
                        status: 'unread'
                    });
                } 
                // 2. Budget Warning Alert (80% to 99%)
                else if (spentPercentage >= 0.8) {
                    await Notification.create({
                        userId,
                        title: "⚠️ Budget Alert",
                        message: `You have spent ${spentPercentageDisplay}% of your ৳${budgetLimit} budget. Only ৳${remainingAmount} remaining!`,
                        status: 'unread'
                    });
                }
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

// ==========================================
// 🗑️ DELETE TRANSACTION LOGIC
// ==========================================
exports.deleteTransaction = async (req, res) => {
    try {
        const transactionId = req.params.id;
        const userId = req.user.id;

        const transaction = await Transaction.findOne({ _id: transactionId, userId: userId });

        if (!transaction) {
            return res.status(404).json({ message: "Transaction not found or unauthorized" });
        }

        await Transaction.findByIdAndDelete(transactionId);

        res.status(200).json({ message: "Transaction deleted successfully" });
    } catch (error) {
        console.error('Delete Transaction Error:', error.message);
        res.status(500).json({ message: "Server error during deleting transaction" });
    }
};