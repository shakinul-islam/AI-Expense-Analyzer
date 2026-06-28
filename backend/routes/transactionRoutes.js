const express = require('express');
const router = express.Router();
const { addTransaction, getTransactions, getSummary } = require('../controllers/transactionController');
const authMiddleware = require('../middleware/authMiddleware'); 


router.post('/', authMiddleware, addTransaction);
router.get('/', authMiddleware, getTransactions);
router.get('/summary', authMiddleware, getSummary);

module.exports = router;