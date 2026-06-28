const express = require('express');
const router = express.Router();
const { getForecasts } = require('../controllers/forecastController');
const auth = require('../middleware/authMiddleware');

router.get('/', auth, getForecasts);
module.exports = router;