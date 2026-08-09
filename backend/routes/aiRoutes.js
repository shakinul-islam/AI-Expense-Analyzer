const express = require('express');
const router = express.Router();
const { generateInsight, classifyTransaction, chatWithAI, extractExpense, getReports } = require('../controllers/aiController');
const auth = require('../middleware/authMiddleware');

router.post('/generate', auth, generateInsight);
router.post('/classify', auth, classifyTransaction);
router.post('/chat', auth, chatWithAI); // Interactive Chat
router.post('/extract', auth, extractExpense); // Smart Auto-fill
router.get('/reports', auth, getReports); // <--- Get Reports Route

module.exports = router;