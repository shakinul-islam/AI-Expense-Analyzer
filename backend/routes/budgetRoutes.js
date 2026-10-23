const express = require('express');
const router = express.Router();
const { setBudget, getBudgets, deleteBudget } = require('../controllers/budgetController');
const auth = require('../middleware/authMiddleware');

router.post('/', auth, setBudget);
router.get('/', auth, getBudgets);
router.delete('/:month/:year', auth, deleteBudget);

module.exports = router;