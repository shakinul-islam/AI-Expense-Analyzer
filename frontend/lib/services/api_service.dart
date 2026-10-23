import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get baseUrl {
    if (kReleaseMode) return "https://your-live-api-url.onrender.com/api";
    if (kIsWeb) return "http://localhost:5000/api";
    try {
      if (Platform.isAndroid) return "http://10.0.2.2:5000/api";
    } catch (_) {}
    return "http://192.168.0.102:5000/api";
  }

  static String? _token;

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

  Future<void> _handle401(http.Response response) async {
    if (response.statusCode == 401) {
      await logout();
      throw Exception('Session expired. Please login again.');
    }
  }

  // ===== AUTH =====
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (data['token'] != null) await _saveToken(data['token']);
        return data;
      }
      throw Exception(data['message'] ?? 'Login failed');
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Cannot connect to server.');
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/register');
      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'email': email, 'password': password}));
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) return data;
      throw Exception(data['message'] ?? 'Registration failed');
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Cannot connect to server.');
    }
  }

  // 🚀 Forgot Password — request OTP (returns message + devOtp)
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final url = Uri.parse('$baseUrl/auth/forgot-password');
      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return data;
      throw Exception(data['message'] ?? 'Failed to send OTP');
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Cannot connect to server.');
    }
  }

  // 🚀 Reset Password — verify OTP + set new password
  Future<String> resetPassword(String email, String otp, String newPassword) async {
    try {
      final url = Uri.parse('$baseUrl/auth/reset-password');
      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'otp': otp,
            'newPassword': newPassword,
          }));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return data['message'] ?? 'Password reset';
      throw Exception(data['message'] ?? 'Failed to reset password');
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('Cannot connect to server.');
    }
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ===== TRANSACTIONS =====
  Future<List<dynamic>> getTransactions() async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/transactions');
    final response = await http.get(url, headers: headers);
    await _handle401(response);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data['data'] is List) return data['data'];
      if (data is List) return data;
    }
    throw Exception('Failed to load transactions');
  }

  Future<List<dynamic>> searchTransactions({
    String? search,
    String? category,
    String? type,
    DateTime? from,
    DateTime? to,
    double? minAmount,
    double? maxAmount,
  }) async {
    final headers = await _getHeaders();
    final params = <String, String>{};
    
    if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (from != null) params['from'] = from.toIso8601String();
    if (to != null) params['to'] = to.toIso8601String();
    if (minAmount != null) params['minAmount'] = minAmount.toString();
    if (maxAmount != null) params['maxAmount'] = maxAmount.toString();

    final uri = Uri.parse('$baseUrl/transactions').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    await _handle401(response);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data['data'] is List) return data['data'];
      if (data is List) return data;
    }
    throw Exception('Failed to search transactions');
  }

  Future<Map<String, dynamic>> addTransaction(Map<String, dynamic> d) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/transactions');
    final response = await http.post(url, headers: headers, body: jsonEncode(d));
    await _handle401(response);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final err = jsonDecode(response.body);
    throw Exception(err['message'] ?? 'Failed to add transaction');
  }

  Future<void> deleteTransaction(String id) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/transactions/$id');
    final response = await http.delete(url, headers: headers);
    await _handle401(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to delete transaction');
    }
  }

  Future<int> bulkDeleteTransactions(List<String> ids) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/transactions/bulk-delete');
    final response = await http.post(url, headers: headers, body: jsonEncode({'ids': ids}));
    await _handle401(response);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['deletedCount'] ?? 0;
    }
    throw Exception('Bulk delete failed');
  }

  Future<String> exportCSV({DateTime? from, DateTime? to}) async {
    final headers = await _getHeaders();
    final params = <String, String>{};
    if (from != null) params['from'] = from.toIso8601String();
    if (to != null) params['to'] = to.toIso8601String();
    final uri = Uri.parse('$baseUrl/transactions/export').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    await _handle401(response);
    if (response.statusCode == 200) return response.body;
    throw Exception('Export failed');
  }

  Future<List<dynamic>> getSummary() async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/transactions/summary');
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? [];
    }
    return [];
  }

  // ===== USER PROFILE =====
  Future<Map<String, dynamic>> getProfile() async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/user/profile');
    final response = await http.get(url, headers: headers);
    await _handle401(response);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load profile');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/user/profile');
    final response = await http.put(url, headers: headers, body: jsonEncode(data));
    await _handle401(response);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to update profile');
  }

  // 🚀 Delete Account
  Future<void> deleteAccount() async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/user/account');
    final response = await http.delete(url, headers: headers);
    await _handle401(response);
    
    if (response.statusCode == 200) {
      await logout(); // Clear token automatically after deletion
      return;
    }
    
    final data = jsonDecode(response.body);
    throw Exception(data['message'] ?? 'Failed to delete account');
  }

  // ===== CUSTOM CATEGORIES =====
  Future<List<String>> getCustomCategories() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/user/categories');
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['customCategories'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> addCustomCategory(String category) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/user/categories');
    final response = await http.post(url, headers: headers, body: jsonEncode({'category': category}));
    await _handle401(response);
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return List<String>.from(data['customCategories'] ?? []);
    }
    throw Exception(data['message'] ?? 'Failed to add category');
  }

  Future<List<String>> deleteCustomCategory(String category) async {
    final headers = await _getHeaders();
    final encoded = Uri.encodeComponent(category);
    final url = Uri.parse('$baseUrl/user/categories/$encoded');
    final response = await http.delete(url, headers: headers);
    await _handle401(response);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return List<String>.from(data['customCategories'] ?? []);
    }
    throw Exception(data['message'] ?? 'Failed to delete category');
  }

  // ===== BUDGET =====
  Future<Map<String, dynamic>> setBudget(double limit, int month, int year) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/budgets');
    final response = await http.post(url, headers: headers,
        body: jsonEncode({'monthly_limit': limit, 'month': month, 'year': year}));
    await _handle401(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to save budget');
  }

  Future<List<dynamic>> getBudgets() async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/budgets');
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ===== NOTIFICATIONS =====
  Future<List<dynamic>> getNotifications() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/notifications');
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (_) {}
    return [];
  }

  Future<void> markNotificationRead(String id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/notifications/$id/read');
      await http.put(url, headers: headers);
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/notifications/$id');
      await http.delete(url, headers: headers);
    } catch (_) {}
  }

  // ===== AI =====
  Future<Map<String, dynamic>> generateInsight() async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/ai/generate');
    final response = await http.post(url, headers: headers);
    await _handle401(response);
    final data = jsonDecode(response.body);
    if (response.statusCode == 201 || response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Failed to generate insight');
  }

  Future<List<dynamic>> getAIReports() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/ai/reports');
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (_) {}
    return [];
  }

  Future<String> autoClassify(String description) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/ai/classify');
      final response = await http.post(url, headers: headers, body: jsonEncode({'description': description}));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['category'] ?? 'Other';
      }
    } catch (_) {}
    return 'Other';
  }

  Future<String> chatWithAI(String query) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/ai/chat');
    final response = await http.post(url, headers: headers, body: jsonEncode({'query': query}));
    await _handle401(response);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['answer'] ?? 'No response.';
    }
    throw Exception('Failed to get AI response');
  }

  Future<Map<String, dynamic>?> extractExpense(String text) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/ai/extract');
      final response = await http.post(url, headers: headers, body: jsonEncode({'text': text}));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
    } catch (_) {}
    return null;
  }
}