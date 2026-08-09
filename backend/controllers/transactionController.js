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
        // 🚀 SMART PROACTIVE BUDGET ALERT LOGIC
        // ==========================================
        if (type === 'Expense') {
            const currentDate = new Date();
            const currentMonth = currentDate.getMonth() + 1; // 1-12
            const currentYear = currentDate.getFullYear();

            // Find budget for this month (or the most recent one)
            const budget = await Budget.findOne({ userId, month: currentMonth, year: currentYear })
                           || await Budget.findOne({ userId }).sort({ createdAt: -1 });

            if (budget && budget.monthly_limit > 0) {
                // Get start and end of the current month
                const startOfMonth = new Date(currentYear, currentMonth - 1, 1);
                const endOfMonth = new Date(currentYear, currentMonth, 0, 23, 59, 59);

                // Calculate total spent THIS month
                const totalSpentAgg = await Transaction.aggregate([
                    { $match: { 
                        userId: new mongoose.Types.ObjectId(userId),
                        type: 'Expense',
                        date: { $gte: startOfMonth, $lte: endOfMonth }
                    }},
                    { $group: { _id: null, total: { $sum: "$amount" } } }
                ]);

                const currentTotal = totalSpentAgg[0]?.total || 0;
                const budgetLimit = budget.monthly_limit;

                // 1. Basic Budget Exceeded Alert
                if (currentTotal > budgetLimit) {
                    await Notification.create({
                        userId,
                        title: "🚨 Budget Exceeded!",
                        message: `You have crossed your monthly budget of ৳${budgetLimit}. Total spent: ৳${currentTotal}.`,
                        status: 'unread'
                    });
                } 
                // 2. Proactive/Predictive Warning
                else {
                    const daysInMonth = new Date(currentYear, currentMonth, 0).getDate();
                    const currentDay = currentDate.getDate();
                    
                    const monthPassedPercentage = currentDay / daysInMonth;
                    const spentPercentage = currentTotal / budgetLimit;

                    // If user spent >= 80% of budget BUT month is less than 80% complete
                    if (spentPercentage >= 0.8 && monthPassedPercentage < 0.8) {
                        
                        // Check if we already sent a proactive warning this month to avoid spamming
                        const existingWarning = await Notification.findOne({
                            userId,
                            title: "⚠️ Proactive Budget Warning",
                            created_at: { $gte: startOfMonth, $lte: endOfMonth }
                        });

                        if (!existingWarning) {
                            await Notification.create({
                                userId,
                                title: "⚠️ Proactive Budget Warning",
                                message: `Slow down! You've already spent ${(spentPercentage * 100).toFixed(0)}% of your budget, but only ${(monthPassedPercentage * 100).toFixed(0)}% of the month has passed.`,
                                status: 'unread'
                            });
                        }
                    }
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

        // Verify the transaction exists and belongs to the user making the request
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