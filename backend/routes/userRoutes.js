const express = require('express');
const router = express.Router();
const {
    getProfile,
    updateProfile,
    deleteAccount,
    addCustomCategory,
    deleteCustomCategory,
    getCustomCategories
} = require('../controllers/userController');
const authMiddleware = require('../middleware/authMiddleware');

router.get('/profile', authMiddleware, getProfile);
router.put('/profile', authMiddleware, updateProfile);
router.delete('/account', authMiddleware, deleteAccount);

router.get('/categories', authMiddleware, getCustomCategories);
router.post('/categories', authMiddleware, addCustomCategory);
router.delete('/categories/:category', authMiddleware, deleteCustomCategory);

module.exports = router;