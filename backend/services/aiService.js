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

const getExpenseInsight = async (transactions) => {
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

        const prompt = `Analyze these expense transactions: ${JSON.stringify(simplifiedData)}. 
        Provide 3 clear, actionable money-saving tips and summarize the spending patterns. Keep it short and professional.`;

        const chatCompletion = await groq.chat.completions.create({
            messages: [{ role: "user", content: prompt }],
            model: "llama-3.3-70b-versatile",
            temperature: 0.7,
            max_tokens: 500,
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

    let insight = "📊 **Spending Analysis Report**\n\n";
    insight += `💰 Total Income: ৳${totalIncome.toFixed(2)}\n`;
    insight += `💸 Total Expenses: ৳${totalSpent.toFixed(2)}\n`;
    insight += `📈 Net Savings: ৳${(totalIncome - totalSpent).toFixed(2)}\n`;
    insight += `📝 Total Transactions: ${transactions.length}\n\n`;
    
    if (totalSpent > 0) {
        insight += "**Top Spending Categories:**\n";
        for (const [category, amount] of sortedCategories.slice(0, 3)) {
            const percentage = ((amount / totalSpent) * 100).toFixed(1);
            insight += `• ${category}: ৳${amount.toFixed(2)} (${percentage}%)\n`;
        }
        
        insight += "\n**💡 Money-Saving Tips:**\n";
        if (sortedCategories.length > 0) {
            insight += `• Consider reducing spending on "${sortedCategories[0][0]}"\n`;
        }
        if (totalSpent > totalIncome * 0.7 && totalIncome > 0) {
            insight += "• Your spending is high relative to income. Create a monthly budget\n";
        }
        if (expenseCount > 20) {
            insight += "• You have many small transactions. Consider tracking daily expenses\n";
        }
        insight += "• Set savings goals and automate transfers\n";
        insight += "• Use the 50/30/20 rule: 50% needs, 30% wants, 20% savings\n";
    } else {
        insight += "No expenses recorded. Start adding your transactions to get insights!";
    }
    
    return insight;
};

module.exports = { getExpenseInsight };