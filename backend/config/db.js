const mongoose = require('mongoose');
require('dotenv').config();

const connectDB = async () => {
    try {
        // Check if db_url exists
        if (!process.env.db_url) {
            console.error('❌ db_url not found in .env file');
            console.error('Please create .env file in backend folder');
            process.exit(1);
        }
        
        const conn = await mongoose.connect(process.env.db_url, {
            serverSelectionTimeoutMS: 5000,
            socketTimeoutMS: 45000,
        });
        
        console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
        console.log(`📁 Database: ${conn.connection.name}`);
    } catch (error) {
        console.error(`❌ MongoDB Error: ${error.message}`);
        console.error('Please make sure MongoDB is running locally');
        console.error('Or check your db_url in .env file');
        process.exit(1);
    }
};

module.exports = connectDB;