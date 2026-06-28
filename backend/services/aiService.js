const Groq = require('groq-sdk');
require('dotenv').config();

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

const getExpenseInsight = async (transactions) => {
    try {
        const simplifiedData = transactions.map(t => ({
            amount: t.amount,
            category: t.category,
            date: t.date,
            type: t.type
        }));

        const prompt = `Analyze these expense transactions: ${JSON.stringify(simplifiedData)}. 
        Provide 3 clear, actionable money-saving tips and summarize the spending patterns. Keep it short.`;

        const chatCompletion = await groq.chat.completions.create({
            messages: [{ role: "user", content: prompt }],
            // Llama 3.3 70B বর্তমানে Groq এর সবচেয়ে জনপ্রিয় এবং স্ট্যাবল মডেল
            model: "llama-3.3-70b-versatile", 
        });

        return chatCompletion.choices[0]?.message?.content;
    } catch (error) {
        console.error("Groq API Error Details:", error.message);
        throw new Error("AI Service is currently unavailable");
    }
};

module.exports = { getExpenseInsight };