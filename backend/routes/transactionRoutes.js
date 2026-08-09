const express = require('express');
const router = express.Router();
const { addTransaction, getTransactions, getSummary, deleteTransaction } = require('../controllers/transactionController');
const authMiddleware = require('../middleware/authMiddleware'); 


router.post('/', authMiddleware, addTransaction);
router.get('/', authMiddleware, getTransactions);
router.get('/summary', authMiddleware, getSummary);
// 👇 Delete route added 👇
router.delete('/:id', authMiddleware, deleteTransaction);

module.exports = router;