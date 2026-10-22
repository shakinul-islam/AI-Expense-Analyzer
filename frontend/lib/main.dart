import 'package:flutter/material.dart';
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/add_transaction_page.dart';
import 'screens/profile_page.dart';
import 'screens/ai_chat_page.dart';
import 'screens/forgot_password_page.dart';
import 'screens/reset_password_page.dart';

void main() => runApp(const ExpenseAnalyzerApp());

class ExpenseAnalyzerApp extends StatelessWidget {
  const ExpenseAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Expense Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[50],
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.indigo, width: 2)),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/add-transaction': (context) => const AddTransactionPage(),
        '/profile': (context) => const ProfilePage(),
        '/ai-chat': (context) => const AiChatPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/reset-password': (context) => const ResetPasswordPage(),
      },
      onGenerateRoute: (settings) {
        // Allow query params for reset-password
        if (settings.name != null && settings.name!.startsWith('/reset-password')) {
          final uri = Uri.parse(settings.name!);
          final token = uri.queryParameters['token'];
          return MaterialPageRoute(
            builder: (_) => ResetPasswordPage(token: token),
          );
        }
        return MaterialPageRoute(builder: (_) => const LandingPage());
      },
    );
  }
}