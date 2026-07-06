import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ===== YOUR IP ADDRESS =====
  static const String baseUrl = "http://192.168.0.102:5000/api";
  
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
      print('📤 Login request to: $url');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      print('📥 Login response: ${response.statusCode}');
      print('📥 Login body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          await _saveToken(data['token']);
        }
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      print('❌ Login error: $e');
      throw Exception('Cannot connect to server. Make sure backend is running.');
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/register');
      print('📤 Register request to: $url');
      print('📤 Data: name=$name, email=$email');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );
      
      print('📥 Register response: ${response.statusCode}');
      print('📥 Register body: ${response.body}');
      
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        String errorMessage = 'Registration failed';
        try {
          final error = jsonDecode(response.body);
          errorMessage = error['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'Server error (${response.statusCode})';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Register error: $e');
      throw Exception('Cannot connect to server. Make sure backend is running.');
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
      
      final response = await http.get(
        url,
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load transactions');
      }
    } catch (e) {
      print('❌ Get transactions error: $e');
      throw Exception('Cannot connect to server');
    }
  }

  Future<Map<String, dynamic>> addTransaction(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/transactions');
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to add transaction');
      }
    } catch (e) {
      print('❌ Add transaction error: $e');
      throw Exception('Cannot connect to server');
    }
  }

  Future<Map<String, dynamic>> getSummary() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/transactions/summary');
      
      final response = await http.get(
        url,
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load summary');
      }
    } catch (e) {
      print('❌ Get summary error: $e');
      return {};
    }
  }

  // ===== USER PROFILE =====
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/user/profile');
      
      final response = await http.get(
        url,
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      print('❌ Get profile error: $e');
      throw Exception('Cannot connect to server');
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/user/profile');
      
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      print('❌ Update profile error: $e');
      throw Exception('Cannot connect to server');
    }
  }

  // ===== NOTIFICATIONS =====
  Future<List<dynamic>> getNotifications() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/notifications');
      
      final response = await http.get(
        url,
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load notifications');
      }
    } catch (e) {
      print('❌ Get notifications error: $e');
      return [];
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/notifications/$id/read');
      
      final response = await http.put(
        url,
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as read');
      }
    } catch (e) {
      print('❌ Mark notification read error: $e');
    }
  }

  // ===== AI =====
  Future<Map<String, dynamic>> generateInsight() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/ai/generate');
      
      final response = await http.post(
        url,
        headers: headers,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to generate insight');
      }
    } catch (e) {
      print('❌ Generate insight error: $e');
      throw Exception('Cannot connect to server');
    }
  }

  Future<List<dynamic>> getAIReports() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/ai/reports');
      
      final response = await http.get(
        url,
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load AI reports');
      }
    } catch (e) {
      print('❌ Get AI reports error: $e');
      return [];
    }
  }
}