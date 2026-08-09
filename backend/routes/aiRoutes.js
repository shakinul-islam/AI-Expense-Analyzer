// backend/routes/aiRoutes.js

const express = require('express');
const router = express.Router();
const { generateInsight, getReports, getForecasts, classifyTransaction } = require('../controllers/aiReportController');
const auth = require('../middleware/authMiddleware');

router.post('/generate', auth, generateInsight);
router.get('/reports', auth, getReports);
router.get('/forecasts', auth, getForecasts);
router.post('/classify', auth, classifyTransaction); 

module.exports = router;