const express = require('express');
const router = express.Router();
const { generateInsight, getReports, getForecasts } = require('../controllers/aiReportController');
const auth = require('../middleware/authMiddleware');

router.post('/generate', auth, generateInsight);
router.get('/reports', auth, getReports);
router.get('/forecasts', auth, getForecasts);

module.exports = router;