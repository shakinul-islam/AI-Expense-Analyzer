const express = require('express');
const router = express.Router();
const {
    getProfile,
    updateProfile,
    addCustomCategory,
    deleteCustomCategory,
    getCustomCategories
} = require('../controllers/userController');
const authMiddleware = require('../middleware/authMiddleware');

router.get('/profile', authMiddleware, getProfile);
router.put('/profile', authMiddleware, updateProfile);

// 🚀 NEW: Custom category routes
router.get('/categories', authMiddleware, getCustomCategories);
router.post('/categories', authMiddleware, addCustomCategory);
router.delete('/categories/:category', authMiddleware, deleteCustomCategory);

module.exports = router;