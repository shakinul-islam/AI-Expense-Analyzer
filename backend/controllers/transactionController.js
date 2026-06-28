const Transaction = require('../models/Transaction');
const Budget = require('../models/Budget');
const Notification = require('../models/Notification');
const mongoose = require('mongoose');

exports.addTransaction = async (req, res) => {
    try {
        const { amount, category, description ,type} = req.body;
        const userId = req.user.id;

  
        const newTransaction = await Transaction.create({ userId, amount, category, description,type });

   
        const budget = await Budget.findOne({ userId }).sort({ createdAt: -1 });

        if (budget) {
           
            const totalSpent = await Transaction.aggregate([
                { $match: { userId: new mongoose.Types.ObjectId(userId) } },
                { $group: { _id: null, total: { $sum: "$amount" } } }
            ]);

            const currentTotal = totalSpent[0]?.total || 0;

           
            if (currentTotal > budget.monthly_limit) {
                await Notification.create({
                    userId,
                    title: "Budget Alert!",
                    message: `সতর্কতা: আপনার খরচ (${currentTotal}) নির্ধারিত বাজেট (${budget.monthly_limit}) অতিক্রম করেছে।`
                });
            }
        }

        res.status(201).json(newTransaction);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};


exports.getTransactions = async (req, res) => {
    try {
        const transactions = await Transaction.find({ userId: req.user.id }).sort({ date: -1 });
        res.status(200).json(transactions);
    } catch (error) {
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
                    count: { $sum: 1 } 
                } 
            },
            
          
            { $sort: { totalAmount: -1 } }
        ]);

        res.status(200).json({
            success: true,
            data: summary
        });
    } catch (error) {
        res.status(500).json({ success: false, message: "Summary generation failed", error: error.message });
    }
};