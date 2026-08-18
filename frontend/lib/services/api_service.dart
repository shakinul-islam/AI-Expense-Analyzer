import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ===== DYNAMIC BASE URL =====
  static String get baseUrl {
    if (kReleaseMode) {
      return "https://your-live-api-url.onrender.com/api";
    }

    if (kIsWeb) {
      return "http://localhost:5000/api";
    }

    try {
      if (Platform.isAndroid) {
        return "http://10.0.2.2:5000/api";
      }
    } catch (e) {
      // Fallback
    }

    return "http://192.168.0.102:5000/api";
  }

  static String? _token;

  // ===== TOKEN MANAGEMENT =====
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    _token = token;
  }

  Future<String?> _getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ===== AUTHENTICATION =====
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['token'] != null) {
          await _saveToken(responseData['token']);
        }
        return responseData;
      } else {
        // 🚀 Throw exact message from backend
        throw Exception(responseData['message'] ?? 'Login failed');
      }
    } catch (e) {
      // If it's our thrown exception, pass it down. Otherwise, generic network error.
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception(
          'Cannot connect to server. Please check your internet connection.');
    }
  }

  Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/register');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return responseData;
      } else {
        // 🚀 Throw exact message from backend
        throw Exception(responseData['message'] ?? 'Registration failed');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception(
          'Cannot connect to server. Please check your internet connection.');
    }
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ===== TRANSACTIONS =====
  Future<List<dynamic>> getTransactions() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/transactions');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load transactions');
      }
    } catch (e) {
      throw Exception('Cannot connect to server');
    }
  }

  Future<Map<String, dynamic>> addTransaction(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/transactions');
      final response =
          await http.post(url, headers: headers, body: jsonEncode(data));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to add transaction');
      }
    } catch (e) {
      throw Exception('Cannot connect to server');
    }
  }

  Future<List<dynamic>> getSummary() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/transactions/summary');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      } else {
        throw Exception('Failed to load summary');
      }
    } catch (e) {
      return [];
    }
  }

  // ===== USER PROFILE =====
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/user/profile');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      throw Exception('Cannot connect to server');
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/user/profile');
      final response =
          await http.put(url, headers: headers, body: jsonEncode(data));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      throw Exception('Cannot connect to server');
    }
  }

  // ===== NOTIFICATIONS =====
  Future<List<dynamic>> getNotifications() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/notifications');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load notifications');
      }
    } catch (e) {
      return [];
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/notifications/$id/read');
      final response = await http.put(url, headers: headers);

      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as read');
      }
    } catch (e) {
      print('❌ Mark notification read error: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/notifications/$id');
      final response = await http.delete(url, headers: headers);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to delete notification');
      }
    } catch (e) {
      print('❌ Delete notification error: $e');
    }
  }

  // ===== AI =====
  Future<Map<String, dynamic>> generateInsight() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/ai/generate');
      final response = await http.post(url, headers: headers);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to generate insight');
      }
    } catch (e) {
      throw Exception('Cannot connect to server');
    }
  }

  Future<List<dynamic>> getAIReports() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/ai/reports');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load AI reports');
      }
    } catch (e) {
      return [];
    }
  }

  Future<String> autoClassify(String description) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/ai/classify');
      final response = await http.post(url,
          headers: headers, body: jsonEncode({'description': description}));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['category'] ?? 'Other';
      }
      return 'Other';
    } catch (e) {
      return 'Other';
    }
  }

  // Interactive AI Chat
  Future<String> chatWithAI(String query) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/ai/chat');
      final response = await http.post(url,
          headers: headers, body: jsonEncode({'query': query}));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['answer'] ?? 'Sorry, no response received.';
      } else {
        throw Exception('Failed to get AI response');
      }
    } catch (e) {
      throw Exception('Cannot connect to server');
    }
  }

  // Smart Text to Expense Extraction
  Future<Map<String, dynamic>?> extractExpense(String text) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/ai/extract');
      final response = await http.post(url,
          headers: headers, body: jsonEncode({'text': text}));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']; // Returns { amount, category, description }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
