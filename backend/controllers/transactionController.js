const Transaction = require('../models/Transaction');
const Budget = require('../models/Budget');
const Notification = require('../models/Notification');
const mongoose = require('mongoose');

exports.addTransaction = async (req, res) => {
    try {
        const { amount, category, description, type } = req.body;
        const userId = req.user.id;

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

        // Budget alert logic
        if (type === 'Expense') {
            const currentDate = new Date();
            const currentMonth = currentDate.getMonth() + 1;
            const currentYear = currentDate.getFullYear();

            let budget = await Budget.findOne({
                userId,
                month: currentMonth,
                year: currentYear
            });

            if (budget && budget.monthly_limit > 0) {
                const startOfMonth = new Date(currentYear, currentMonth - 1, 1);
                const endOfMonth = new Date(currentYear, currentMonth, 0, 23, 59, 59);
                const budgetLimit = budget.monthly_limit;

                const totalSpentAgg = await Transaction.aggregate([
                    {
                        $match: {
                            userId: new mongoose.Types.ObjectId(userId),
                            type: 'Expense',
                            date: { $gte: startOfMonth, $lte: endOfMonth }
                        }
                    },
                    { $group: { _id: null, total: { $sum: "$amount" } } }
                ]);

                const currentTotal = totalSpentAgg[0]?.total || 0;
                const spentPercentage = currentTotal / budgetLimit;
                const spentPercentageDisplay = Math.round(spentPercentage * 100);
                const remainingAmount = budgetLimit - currentTotal;

                if (spentPercentage >= 1.0) {
                    await Notification.create({
                        userId,
                        title: "🚨 Budget Exceeded!",
                        message: `You have crossed your budget limit! You spent ${spentPercentageDisplay}% of your ৳${budgetLimit} budget. Total spent: ৳${currentTotal}.`,
                        status: 'unread'
                    });
                } else if (spentPercentage >= 0.8) {
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

// 🚀 FIXED: Search + filter + pagination
exports.getTransactions = async (req, res) => {
    try {
        const userId = req.user.id;
        const {
            search,
            category,
            type,
            from,
            to,
            minAmount,
            maxAmount,
            page = 1,
            limit = 100
        } = req.query;

        const filter = { userId };

        // 🚀 FIX: Proper case-insensitive search across category & description
        if (search && search.trim() !== '') {
            const searchRegex = new RegExp(search.trim(), 'i');
            filter.$or = [
                { category: searchRegex },
                { description: searchRegex }
            ];
        }

        if (category) filter.category = category;
        if (type && ['Income', 'Expense'].includes(type)) filter.type = type;

        if (from || to) {
            filter.date = {};
            if (from) filter.date.$gte = new Date(from);
            if (to) filter.date.$lte = new Date(to);
        }

        if (minAmount || maxAmount) {
            filter.amount = {};
            if (minAmount) filter.amount.$gte = Number(minAmount);
            if (maxAmount) filter.amount.$lte = Number(maxAmount);
        }

        const skip = (Number(page) - 1) * Number(limit);
        const total = await Transaction.countDocuments(filter);
        const transactions = await Transaction.find(filter)
            .sort({ date: -1 })
            .skip(skip)
            .limit(Number(limit));

        res.status(200).json({
            data: transactions,
            total,
            page: Number(page),
            totalPages: Math.ceil(total / Number(limit))
        });
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
                        $sum: { $cond: [{ $eq: ["$type", "Income"] }, "$amount", 0] }
                    },
                    expense: {
                        $sum: { $cond: [{ $eq: ["$type", "Expense"] }, "$amount", 0] }
                    }
                }
            },
            { $sort: { totalAmount: -1 } }
        ]);

        res.status(200).json({ success: true, data: summary });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Summary generation failed",
            error: error.message
        });
    }
};

exports.deleteTransaction = async (req, res) => {
    try {
        const transactionId = req.params.id;
        const userId = req.user.id;

        const transaction = await Transaction.findOne({ _id: transactionId, userId });
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

// 🚀 Bulk delete
exports.bulkDeleteTransactions = async (req, res) => {
    try {
        const { ids } = req.body;
        if (!Array.isArray(ids) || ids.length === 0) {
            return res.status(400).json({ message: "ids must be a non-empty array" });
        }

        const result = await Transaction.deleteMany({
            _id: { $in: ids },
            userId: req.user.id
        });

        res.status(200).json({
            message: `${result.deletedCount} transaction(s) deleted`,
            deletedCount: result.deletedCount
        });
    } catch (error) {
        console.error('Bulk Delete Error:', error.message);
        res.status(500).json({ message: "Server error during bulk delete" });
    }
};

exports.exportCSV = async (req, res) => {
    try {
        const userId = req.user.id;
        const { from, to, category, type } = req.query;

        const filter = { userId };
        if (category) filter.category = category;
        if (type && ['Income', 'Expense'].includes(type)) filter.type = type;
        if (from || to) {
            filter.date = {};
            if (from) filter.date.$gte = new Date(from);
            if (to) filter.date.$lte = new Date(to);
        }

        const transactions = await Transaction.find(filter).sort({ date: -1 });

        const escape = (v) => {
            if (v === null || v === undefined) return '';
            const s = String(v);
            if (s.includes(',') || s.includes('"') || s.includes('\n')) {
                return `"${s.replace(/"/g, '""')}"`;
            }
            return s;
        };

        const header = 'Date,Type,Category,Description,Amount\n';
        const rows = transactions.map(t => {
            const date = new Date(t.date).toISOString().split('T')[0];
            return [
                date,
                t.type,
                t.category,
                escape(t.description || ''),
                t.amount
            ].join(',');
        }).join('\n');

        const csv = header + rows;

        res.setHeader('Content-Type', 'text/csv; charset=utf-8');
        res.setHeader(
            'Content-Disposition',
            `attachment; filename="transactions_${Date.now()}.csv"`
        );
        res.status(200).send('\uFEFF' + csv); // BOM for Excel
    } catch (error) {
        console.error('Export CSV Error:', error.message);
        res.status(500).json({ message: "Export failed" });
    }
};