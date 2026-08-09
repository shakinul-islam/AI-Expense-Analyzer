const Groq = require('groq-sdk');
require('dotenv').config();

// Get API key from environment
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

const getExpenseInsight = async (transactions, userProfile = {}) => {
    try {
        // If Groq is not initialized, return fallback
        if (!groq) {
            console.log('⚠️ Using fallback insight generator');
            return generateFallbackInsight(transactions);
        }

        console.log('🤖 Generating AI insight using Groq...');
        
        const simplifiedData = transactions.map(t => ({
            amount: t.amount,
            category: t.category,
            date: t.date,
            type: t.type
        }));

        const currency = userProfile.currency || 'BDT';
        const savingsGoal = userProfile.savingsGoal || 0;

        // Structured prompt fulfilling FR-05, FR-06, and FR-09 with strict formatting rules
        const prompt = `
        You are an advanced AI Financial Advisor. Analyze the following user transaction data:
        ${JSON.stringify(simplifiedData)}
        
        User Context:
        - Target Currency: ${currency}
        - Monthly Savings Goal: ${savingsGoal} ${currency}

        Provide a highly structured, user-friendly, and concise financial report. 
        CRITICAL RULES:
        - Do NOT include any introductory or concluding conversational text (e.g., "Here is your report").
        - Use exactly the formatting and structure provided below.
        - Keep the text short, direct, and actionable.

        ### 📊 1. Spending Trend Insight
        [Write a concise, 2-3 sentence paragraph analyzing underlying waste, identifying patterns of overspending, and summarizing current financial discipline.]

        ### 💡 2. Personalized Budget Advice
        [Evaluate current month trends against the fixed savings goal of ${savingsGoal} ${currency}. Provide exactly 3 actionable, proactive advice prompts to optimize savings. Use bullet points.]
        * **[Short Title]:** [Brief actionable explanation]
        * **[Short Title]:** [Brief actionable explanation]
        * **[Short Title]:** [Brief actionable explanation]

        ### 🔮 3. Predictive Budget Forecasting
        [Based on historical data, forecast the baseline spending for the next month for the top 3 categories. Use bullet points.]
        * **[Category 1]:** [Estimated Amount] ${currency}
        * **[Category 2]:** [Estimated Amount] ${currency}
        * **[Category 3]:** [Estimated Amount] ${currency}
        `;

        const chatCompletion = await groq.chat.completions.create({
            messages: [{ role: "user", content: prompt }],
            model: "llama-3.3-70b-versatile",
            temperature: 0.5, // Lowered temperature slightly for more consistent formatting
            max_tokens: 600,
        });

        const result = chatCompletion.choices[0]?.message?.content;
        console.log('✅ AI insight generated successfully');
        return result;

    } catch (error) {
        console.error("❌ Groq API Error:", error.message);
        console.log('⚠️ Falling back to local insight generator');
        return generateFallbackInsight(transactions);
    }
};

// Automated Classification (FR-04)
const autoClassifyTransaction = async (description) => {
    try {
        if (!groq) return "Other";

        const prompt = `Classify this expense description into exactly ONE of these categories: Food, Transport, Shopping, Entertainment, Bills, Health, Education, Salary, Investment, Other. 
        Description: "${description}". 
        Reply with JUST the exact category name. Nothing else.`;

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
        console.error("❌ Groq Classification Error:", error.message);
        return "Other";
    }
};

// Fallback insight generator
const generateFallbackInsight = (transactions) => {
    if (!transactions || transactions.length === 0) {
        return "📊 No transactions found. Start adding your expenses to get insights!";
    }

    // Calculate totals
    const categoryTotals = {};
    let totalSpent = 0;
    let totalIncome = 0;
    let expenseCount = 0;
    
    for (const t of transactions) {
        if (t.type === 'Expense') {
            const category = t.category || 'Uncategorized';
            categoryTotals[category] = (categoryTotals[category] || 0) + t.amount;
            totalSpent += t.amount;
            expenseCount++;
        } else if (t.type === 'Income') {
            totalIncome += t.amount;
        }
    }

    // Sort categories by amount
    const sortedCategories = Object.entries(categoryTotals)
        .sort((a, b) => b[1] - a[1]);

    let insight = "### 📊 1. Spending Analysis Report\n\n";
    insight += `* **Total Income:** ৳${totalIncome.toFixed(2)}\n`;
    insight += `* **Total Expenses:** ৳${totalSpent.toFixed(2)}\n`;
    insight += `* **Net Savings:** ৳${(totalIncome - totalSpent).toFixed(2)}\n`;
    insight += `* **Total Transactions:** ${transactions.length}\n\n`;
    
    if (totalSpent > 0) {
        insight += "### 💡 2. Top Spending Categories\n\n";
        for (const [category, amount] of sortedCategories.slice(0, 3)) {
            const percentage = ((amount / totalSpent) * 100).toFixed(1);
            insight += `* **${category}:** ৳${amount.toFixed(2)} (${percentage}%)\n`;
        }
        
        insight += "\n### 🔮 3. Money-Saving Tips\n\n";
        if (sortedCategories.length > 0) {
            insight += `* **Reduce Category Cost:** Consider reducing spending on "${sortedCategories[0][0]}".\n`;
        }
        if (totalSpent > totalIncome * 0.7 && totalIncome > 0) {
            insight += "* **Budget Check:** Your spending is high relative to income. Create a strict monthly budget.\n";
        }
        if (expenseCount > 20) {
            insight += "* **Micro-transactions:** You have many small transactions. Consider tracking daily minimal expenses.\n";
        }
        insight += "* **The 50/30/20 Rule:** Try 50% needs, 30% wants, and 20% savings.\n";
    } else {
        insight += "No expenses recorded. Start adding your transactions to get insights!";
    }
    
    return insight;
};

module.exports = { getExpenseInsight, autoClassifyTransaction };