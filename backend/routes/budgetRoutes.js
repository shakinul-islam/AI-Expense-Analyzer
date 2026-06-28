const express = require('express');
const router = express.Router();
const { setBudget, getBudgets } = require('../controllers/budgetController');
const auth = require('../middleware/authMiddleware');

router.post('/', auth, setBudget);
router.get('/', auth, getBudgets);
module.exports = router;