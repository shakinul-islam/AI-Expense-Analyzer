const express = require('express');
const router = express.Router();
const {
    addTransaction,
    getTransactions,
    getSummary,
    deleteTransaction,
    bulkDeleteTransactions,
    exportCSV
} = require('../controllers/transactionController');
const authMiddleware = require('../middleware/authMiddleware');

router.post('/', authMiddleware, addTransaction);
router.get('/', authMiddleware, getTransactions);
router.get('/summary', authMiddleware, getSummary);
router.get('/export', authMiddleware, exportCSV);
router.delete('/:id', authMiddleware, deleteTransaction);
router.post('/bulk-delete', authMiddleware, bulkDeleteTransactions);

module.exports = router;