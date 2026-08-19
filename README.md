# AI Expense Analyzer

## Project Overview
The AI Expense Analyzer is an advanced personal finance management application developed using the Flutter framework for the frontend, Node.js and Express.js for the backend, and MongoDB for data persistence. Unlike traditional ledgers, this system integrates state-of-the-art machine learning capabilities via the **Groq API (Llama 3 Models)** to bridge the gap between simple financial tracking and contextual financial management.

## Team Information
* **Team Name:** CSE4204-8A-T04
* **Team Members:**
    * Md. Shakinul Islam (Team Leader - Database Management & Testing)
    * Naim Sheikh (Frontend Development & UI Design)
    * Ayon Banerjee (Backend Development)
    * Afia Rahman (AI Integration & Documentation)

## Key Features & Objectives
* **Secure Authentication:** JWT-based user login and registration with bcrypt password hashing.
* **Intelligent Transaction Logger:** Seamless recording of daily income and expenses with an AI-powered "Magic Fill" feature that extracts details and categorizes transactions from natural language inputs.
* **Interactive AI Financial Assistant:** A dedicated AI chatbot capable of answering specific financial queries and providing real-time, data-driven account snapshots.
* **AI-Driven Financial Analysis:** Deep-level analysis to identify spending trends, habitual overspending patterns, and generate structured, actionable financial insight reports.
* **Smart Notification Dispatcher:** Automated, real-time alerts that notify users when they reach critical budget thresholds (e.g., 80% of the monthly limit).

## Technology Stack
* **Frontend:** Flutter, Dart
* **Backend:** Node.js, Express.js
* **Database:** MongoDB Atlas
* **AI Integration:** Groq API (`llama-3.3-70b-versatile` & `llama-3.1-8b-instant`)

## Repository Structure
```text
/
├── ai/               # AI prompts and sample payloads for all AI features
├── backend/          # Node.js + Express.js API source code
├── frontend/         # Flutter application source code
├── database/         # Database schemas and ER diagrams
├── documentation/    # System Design PDF, SRS, and project reports
├── design/           # UI/UX wireframes and User Flow diagrams
├── screenshots/      # App screenshots and integration proofs
├── README.md         # Project documentation
└── .gitignore        # Git ignore file
