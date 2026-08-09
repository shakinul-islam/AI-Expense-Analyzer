const Groq = require('groq-sdk');
require('dotenv').config();

const GROQ_API_KEY = process.env.GROQ_API_KEY;

let groq = null;
if (GROQ_API_KEY && GROQ_API_KEY.startsWith('gsk_')) {
    try {
        groq = new Groq({ apiKey: GROQ_API_KEY });
        console.log('✅ Groq AI Service initialized successfully');
    } catch (error) {
        console.error('❌ Failed to initialize Groq:', error.message);
    }
} else {
    console.log('⚠️ Groq API key not found or invalid. AI features will use fallback mode.');
}

// 1. Generate Insight (FR-05, FR-06, FR-09)
const getExpenseInsight = async (transactions, userProfile = {}) => {
    try {
        if (!groq) return "📊 AI is currently running in fallback mode.";

        const simplifiedData = transactions.map(t => ({ amount: t.amount, category: t.category, date: t.date, type: t.type }));
        const currency = userProfile.currency || 'BDT';
        const savingsGoal = userProfile.savingsGoal || 0;

        const prompt = `
        You are an advanced AI Financial Advisor. Analyze this data: ${JSON.stringify(simplifiedData)}
        Context: Currency: ${currency}, Monthly Savings Goal: ${savingsGoal} ${currency}.
        Provide a structured, user-friendly financial report in English. 
        RULES: No intro/outro text. Use exactly this formatting:

        ### 📊 1. Spending Trend Insight
        [2-3 sentences analyzing waste and financial discipline]

        ### 💡 2. Personalized Budget Advice
        * **[Short Title]:** [Advice]
        * **[Short Title]:** [Advice]
        * **[Short Title]:** [Advice]

        ### 🔮 3. Predictive Budget Forecasting
        * **[Category 1]:** [Amount] ${currency}
        * **[Category 2]:** [Amount] ${currency}
        * **[Category 3]:** [Amount] ${currency}
        `;

        const chatCompletion = await groq.chat.completions.create({
            messages: [{ role: "user", content: prompt }],
            model: "llama-3.3-70b-versatile",
            temperature: 0.5,
            max_tokens: 600,
        });

        return chatCompletion.choices[0]?.message?.content;
    } catch (error) {
        console.error("❌ Groq API Error:", error.message);
        return "Failed to generate insight.";
    }
};

// 2. Automated Classification (FR-04)
const autoClassifyTransaction = async (description) => {
    try {
        if (!groq) return "Other";

        const prompt = `Classify this expense into exactly ONE category: Food, Transport, Shopping, Entertainment, Bills, Health, Education, Salary, Investment, Other. 
        Description: "${description}". Reply ONLY with the category name.`;

        const chatCompletion = await groq.chat.completions.create({
            messages: [{ role: "user", content: prompt }],
            model: "llama-3.3-70b-versatile",
            temperature: 0.1,
            max_tokens: 10,
        });

        const category = chatCompletion.choices[0]?.message?.content.trim();
        const validCategories = ['Food', 'Transport', 'Shopping', 'Entertainment', 'Bills', 'Health', 'Education', 'Salary', 'Investment', 'Other'];
        return validCategories.includes(category) ? category : "Other";
    } catch (error) {
        return "Other";
    }
};

// 3. Interactive AI Chat (New Feature)
const askFinancialAssistant = async (query, contextData) => {
    try {
        if (!groq) return "Sorry, AI assistant is currently unavailable.";

        const prompt = `
        You are a smart, polite financial assistant.
        User's Financial Summary:
        - Monthly Income: ${contextData.income}
        - Total Spent: ${contextData.totalSpent}
        - Remaining Balance: ${contextData.remaining}
        - Recent Expenses: ${JSON.stringify(contextData.expenses)}

        User Query: "${query}"
        
        Answer the user's question clearly and directly in English. Do not show unnecessary calculation steps. Give a clean, professional answer based on the numbers provided.
        `;

        const chatCompletion = await groq.chat.completions.create({
            messages: [{ role: "user", content: prompt }],
            model: "llama-3.1-8b-instant",
            temperature: 0.5,
            max_tokens: 300,
        });

        return chatCompletion.choices[0]?.message?.content;
    } catch (error) {
        console.error("❌ Chat API Error:", error.message);
        return "I encountered an error while processing your request.";
    }
};

// 4. Smart Text to Expense Extraction (New Feature)
const extractExpenseDetails = async (text) => {
    try {
        if (!groq) return null;

        const prompt = `
        You are an expert financial assistant. Extract expense details from this input: "${text}".
        Categories allowed: Food, Transport, Shopping, Entertainment, Bills, Health, Education, Salary, Investment, Other.
        
        Respond ONLY with a valid JSON object. No extra text or markdown formatting.
        Format strictly like this:
        {
          "amount": 500,
          "category": "Food",
          "description": "KFC Burger"
        }
        `;

        const chatCompletion = await groq.chat.completions.create({
            messages: [{ role: "user", content: prompt }],
            model: "llama-3.1-8b-instant",
            temperature: 0.1,
            response_format: { type: "json_object" },
        });

        return JSON.parse(chatCompletion.choices[0]?.message?.content);
    } catch (error) {
        console.error("❌ Extraction Error:", error.message);
        return null;
    }
};

module.exports = { getExpenseInsight, autoClassifyTransaction, askFinancialAssistant, extractExpenseDetails };