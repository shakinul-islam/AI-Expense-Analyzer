const express = require('express');
const router = express.Router();
const {
    generateInsight,
    classifyTransaction,
    chatWithAI,
    extractExpense,
    getReports,
    deleteReport
} = require('../controllers/aiController');
const auth = require('../middleware/authMiddleware');

router.post('/generate', auth, generateInsight);
router.post('/classify', auth, classifyTransaction);
router.post('/chat', auth, chatWithAI);
router.post('/extract', auth, extractExpense);
router.get('/reports', auth, getReports);
router.delete('/reports/:id', auth, deleteReport);

module.exports = router;