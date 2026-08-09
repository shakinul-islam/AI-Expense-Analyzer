// Configure DNS servers before connecting to MongoDB
const dns = require('dns');
dns.setServers(['8.8.8.8', '1.1.1.1']);

// Load .env FIRST
require('dotenv').config();

const express = require('express');
const app = express();
const port = process.env.PORT || 5000;
const cors = require('cors');
const connectDB = require('./config/db');

// Check environment variables
console.log('🔍 Checking environment...');
console.log('📁 NODE_ENV:', process.env.NODE_ENV || 'development');

if (process.env.db_url) {
    console.log('✅ db_url found');
} else {
    console.error('❌ db_url not found in .env');
    console.error('Please create .env file in backend folder');
    process.exit(1);
}

if (process.env.JWT_SECRET) {
    console.log('✅ JWT_SECRET found');
} else {
    console.warn('⚠️ JWT_SECRET not found - using default');
}

if (process.env.GROQ_API_KEY && process.env.GROQ_API_KEY.startsWith('gsk_')) {
    console.log('✅ GROQ_API_KEY found');
} else {
    console.warn('⚠️ GROQ_API_KEY not found or invalid (AI features will use fallback)');
}

// Middleware
app.use(express.json());

app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));

// Routes
const authRoutes = require('./routes/authRoutes');
const transactionRoutes = require('./routes/transactionRoutes');
const budgetRoutes = require('./routes/budgetRoutes');
const forecastRoutes = require('./routes/forecastRoutes');
const aiRoutes = require('./routes/aiRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const userRoutes = require('./routes/userRoutes');

// Register routes
app.use('/api/auth', authRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/budgets', budgetRoutes);
app.use('/api/forecasts', forecastRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/user', userRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        message: 'Server is running',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'development'
    });
});

// Global error handler
app.use((err, req, res, next) => {
    console.error('❌ Global Error:', err.message);

    res.status(500).json({
        message: 'Internal server error',
        error: process.env.NODE_ENV === 'development'
            ? err.message
            : undefined
    });
});

// Connect to MongoDB and start server
connectDB();

app.listen(port, '0.0.0.0', () => {
    console.log(`🚀 Server running at http://localhost:${port}`);
    console.log(`📱 Access from your IP: http://192.168.0.102:${port}`);
});