const express = require('express');
const app = express();
const port = 5000;
const cors = require('cors')
const connectDB = require('./config/db');

app.use(express.json()); 
app.use(cors())


const authRoutes = require('./routes/authRoutes');
const transactionRoutes = require('./routes/transactionRoutes');
const budgetRoutes = require('./routes/budgetRoutes');
const forecastRoutes = require('./routes/forecastRoutes');
const aiRoutes = require('./routes/aiRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const userRoutes = require('./routes/userRoutes');
// const aiRoutes = require('./routes/aiRoutes');


app.use('/api/auth', authRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/budgets', budgetRoutes);
app.use('/api', aiRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/user', userRoutes);  
// app.use('/api/ai', aiRoutes);






connectDB();

app.listen(port,()=>{
    console.log(`server running at http://localhost:${port}`)
})