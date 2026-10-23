import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../utils/currency_helper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> _userData = {};
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  bool _isEditing = false;
  
  final _nameController = TextEditingController();
  final _currencyController = TextEditingController();
  final _savingsGoalController = TextEditingController();
  String _selectedCurrency = 'BDT';
  
  // 🚀 Profile Picture Variables
  String? _base64Image;
  Uint8List? _webImage;
  File? _mobileImage;

  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;

  final List<String> _currencies = ['BDT', 'USD', 'EUR', 'GBP', 'INR', 'CAD', 'AUD', 'JPY'];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        ApiService().getProfile(),
        ApiService().getTransactions(),
      ]);

      final profileData = responses[0] as Map<String, dynamic>;
      final transactionsData = responses[1] as List<dynamic>;

      _calculateTotals(transactionsData);

      setState(() {
        _userData = profileData;
        _transactions = transactionsData;
        _nameController.text = profileData['name'] ?? '';
        _currencyController.text = profileData['currency'] ?? 'BDT';
        _selectedCurrency = profileData['currency'] ?? 'BDT';
        _savingsGoalController.text = (profileData['savingsGoal'] ?? 0).toString();
        _base64Image = profileData['profilePicture']; // Load saved image
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${e.toString().replaceAll('Exception:', '')}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _calculateTotals(List<dynamic> transactions) {
    double income = 0;
    double expenses = 0;
    for (var tx in transactions) {
      final amount = (tx['amount'] ?? 0).toDouble();
      if (tx['type'] == 'Income') {
        income += amount;
      } else if (tx['type'] == 'Expense') {
        expenses += amount;
      }
    }
    _totalIncome = income;
    _totalExpenses = expenses;
  }

  // 🚀 Pick Image Logic with Auto-Resize
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200, 
        maxHeight: 200,
        imageQuality: 40, 
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        
        if (bytes.length > 500 * 1024) {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image is too large. Please choose a smaller one.'), backgroundColor: Colors.orange),
            );
           }
           return;
        }

        setState(() {
          _base64Image = base64Encode(bytes);
          if (kIsWeb) {
            _webImage = bytes;
          } else {
            _mobileImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService().updateProfile({
        'full_name': _nameController.text.trim(),
        'currency': _selectedCurrency,
        'savings_goal': double.tryParse(_savingsGoalController.text) ?? 0,
        'profile_picture': _base64Image, 
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile updated successfully!'), backgroundColor: Colors.green),
        );
        setState(() => _isEditing = false);
        await _loadProfileData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${e.toString().replaceAll('Exception:', '')}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🚀 Show Delete Account Confirmation Dialog
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text(
            'This will permanently delete your account, along with ALL your transactions, budgets, and notifications.\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog first
              setState(() => _isLoading = true);
              try {
                await ApiService().deleteAccount();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account deleted successfully'), backgroundColor: Colors.green),
                  );
                  Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception:', '')}'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ApiService().logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Helper to display image
  Widget _buildProfileImage() {
    if (_base64Image != null && _base64Image!.isNotEmpty) {
      try {
        final bytes = base64Decode(_base64Image!);
        return ClipOval(
          child: Image.memory(
            bytes,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        // Fallback if decode fails
      }
    }
    // Default Avatar with Initial
    return Text(
      _userData['name']?.isNotEmpty == true ? _userData['name'][0].toUpperCase() : 'U',
      style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.indigo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _updateProfile,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.shade50, Colors.white],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 🚀 Profile Avatar with Edit Icon
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.indigo, Colors.purple]),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            child: _buildProfileImage(),
                          ),
                        ),
                        if (_isEditing)
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.indigo,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _userData['name'] ?? 'User',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      _userData['email'] ?? '',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // Stats Cards
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Total Income', CurrencyHelper.format(_totalIncome, _currency), Colors.green, Icons.trending_up)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Total Expenses', CurrencyHelper.format(_totalExpenses, _currency), Colors.red, Icons.trending_down)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Transactions', _transactions.length.toString(), Colors.blue, Icons.receipt_long)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Savings Goal', CurrencyHelper.format((_userData['savingsGoal'] ?? 0), _currency), Colors.orange, Icons.savings)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Profile Details Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.person_outline, color: Colors.indigo),
                                SizedBox(width: 8),
                                Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildEditableField('Full Name', _nameController, _isEditing, Icons.person),
                            const Divider(height: 24),
                            _buildEditableDropdownField('Currency', _selectedCurrency, _currencies, _isEditing, Icons.currency_exchange),
                            const Divider(height: 24),
                            _buildEditableField('Savings Goal (Monthly)', _savingsGoalController, _isEditing, Icons.savings, isNumeric: true, hintText: '0.00'),
                            const Divider(height: 24),
                            _buildInfoRow('Member Since', _userData['createdAt'] != null ? _formatDate(_userData['createdAt']) : 'N/A', Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 🚀 Delete Account Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: _showDeleteAccountDialog,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          backgroundColor: Colors.red.shade50,
                        ),
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text('Delete Account', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text('Logout', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  String get _currency => _userData['currency'] ?? 'BDT';

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(flex: 1, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14))),
          Expanded(flex: 1, child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, bool isEditing, IconData icon, {bool isNumeric = false, String hintText = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(flex: 1, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14))),
          Expanded(
            flex: 1,
            child: isEditing
                ? TextFormField(
                    controller: controller,
                    keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onFieldSubmitted: (_) => _updateProfile(),
                  )
                : Text(controller.text.isEmpty ? 'Not set' : controller.text, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableDropdownField(String label, String selectedValue, List<String> options, bool isEditing, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(flex: 1, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14))),
          Expanded(
            flex: 1,
            child: isEditing
                ? DropdownButton<String>(
                    value: options.contains(selectedValue) ? selectedValue : options.first,
                    isExpanded: true,
                    alignment: Alignment.centerRight,
                    underline: const SizedBox(),
                    items: options.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text('$value (${CurrencyHelper.symbol(value)})', textAlign: TextAlign.right),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) setState(() => _selectedCurrency = newValue);
                    },
                  )
                : Text(selectedValue, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    _savingsGoalController.dispose();
    super.dispose();
  }
}