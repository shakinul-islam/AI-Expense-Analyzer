// ignore_for_file: unused_field, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'add_transaction_page.dart';
import 'profile_page.dart';
import 'ai_chat_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<dynamic> _transactions = [];
  List<dynamic> _filteredTransactions = []; // 🚀 New: To store month-wise data
  List<dynamic> _allBudgets = []; // 🚀 New: To store all budgets

  Map<String, dynamic> _userData = {};
  List<dynamic> _notifications = [];
  int _selectedIndex = 0; // 0: Home, 1: Insights
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _error = '';

  // 🚀 New: Selected Month state
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  double _totalIncome = 0;
  double _totalExpense = 0;
  double _balance = 0;
  double _monthlyBudget = 0;

  final List<Color> _chartColors = [
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFEF4444), // Red
    const Color(0xFF10B981), // Teal
    const Color(0xFF6366F1), // Indigo
    const Color(0xFFEC4899), // Pink
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      await _loadTransactions();
      await _loadProfile();
      await _loadNotifications();
      await _loadBudget();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception:', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final transactions = await ApiService().getTransactions();
      setState(() {
        _transactions = transactions;
        _filterDataByMonth(); // 🚀 Apply filter after fetching
      });
    } catch (e) {
      throw Exception('Failed to load transactions');
    }
  }

  Future<void> _loadProfile() async {
    try {
      final userData = await ApiService().getProfile();
      setState(() {
        _userData = userData;
      });
    } catch (e) {
      // Profile is optional
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await ApiService().getNotifications();
      setState(() {
        _notifications = notifications;
      });
    } catch (e) {
      // Notifications are optional
    }
  }

  Future<void> _loadBudget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/budgets'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _allBudgets = jsonDecode(response.body);
        _filterDataByMonth(); // 🚀 Apply filter to select budget for the month
      }
    } catch (e) {
      print('Load budget error: $e');
    }
  }

  // 🚀 New Method: Filters data based on selected month
  void _filterDataByMonth() {
    setState(() {
      // Filter transactions
      _filteredTransactions = _transactions.where((t) {
        if (t['date'] == null) return false;
        DateTime date = DateTime.parse(t['date']).toLocal();
        return date.year == _selectedMonth.year &&
            date.month == _selectedMonth.month;
      }).toList();

      // Extract budget for selected month
      final currentBudgets = _allBudgets
          .cast<Map<String, dynamic>>()
          .where((b) =>
              b['month'] == _selectedMonth.month &&
              b['year'] == _selectedMonth.year)
          .toList();

      if (currentBudgets.isNotEmpty) {
        _monthlyBudget = (currentBudgets.last['monthly_limit'] ?? 0).toDouble();
      } else {
        _monthlyBudget = 0;
      }

      _calculateTotals();
    });
  }

  Future<void> _saveBudget(double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/budgets'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'monthly_limit': amount,
          'month': _selectedMonth.month, // 🚀 Save budget for selected month
          'year': _selectedMonth.year,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() {
          _monthlyBudget = amount;
          // Refresh budgets in background
          _loadBudget();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(amount == 0
                ? 'Budget removed'
                : 'Budget updated successfully!'),
            backgroundColor: amount == 0 ? Colors.orange : Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Failed to update budget'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
      );
    }
  }

  void _showBudgetDialog() {
    final TextEditingController budgetController = TextEditingController(
      text: _monthlyBudget > 0 ? _monthlyBudget.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Budget: ${DateFormat('MMM yyyy').format(_selectedMonth)}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set a limit for your expenses this month to receive proactive AI alerts.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: budgetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Budget Amount',
                prefixText: '৳ ',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: Colors.indigo, width: 2)),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          if (_monthlyBudget > 0)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveBudget(0);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(budgetController.text) ?? 0;
              Navigator.pop(context);
              _saveBudget(amount);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            child: const Text('Save',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(String id) async {
    setState(() {
      _transactions.removeWhere((t) => t['_id'] == id);
      _filterDataByMonth(); // Re-filter after delete
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/transactions/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Transaction deleted successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
        );
      }
    } catch (e) {
      print('Delete error: $e');
    }
  }

  void _calculateTotals() {
    _totalIncome = 0;
    _totalExpense = 0;

    for (var transaction in _filteredTransactions) {
      final amount = (transaction['amount'] ?? 0).toDouble();
      if (transaction['type'] == 'Income') {
        _totalIncome += amount;
      } else {
        _totalExpense += amount;
      }
    }
    _balance = _totalIncome - _totalExpense;
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _loadAllData();
    setState(() => _isRefreshing = false);
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              ApiService().logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _navigateToAddTransaction() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionPage()),
    ).then((result) {
      if (result == true) _refreshData();
    });
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    ).then((_) => _refreshData());
  }

  void _navigateToAiChat() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AiChatPage()));
  }

  void _onBottomNavTap(int index) {
    if (index == 0 || index == 1) {
      setState(() => _selectedIndex = index);
    } else if (index == 2) {
      _navigateToAiChat();
    } else if (index == 3) {
      _navigateToProfile();
    }
  }

  int _getUnreadNotificationCount() {
    return _notifications.where((n) => n['status'] == 'unread').length;
  }

  String _formatToBDTime(String? dateString) {
    if (dateString == null) return '';
    try {
      DateTime parsedUTC = DateTime.parse(dateString).toUtc();
      DateTime bdTime = parsedUTC.add(const Duration(hours: 6));
      return DateFormat('MMM dd, yyyy - hh:mm a').format(bdTime);
    } catch (e) {
      return '';
    }
  }

  String _formatNotificationMessage(String originalMsg) {
    if (_monthlyBudget > 0 && originalMsg.contains('budget of')) {
      return originalMsg.replaceAll(RegExp(r'budget of ৳[0-9]+'),
          'budget of ৳${_monthlyBudget.toStringAsFixed(0)}');
    }
    return originalMsg;
  }

  // 🚀 New: Generate list of last 12 months dynamically
  List<DateTime> _generateMonthsList() {
    List<DateTime> months = [];
    DateTime now = DateTime.now();
    DateTime current = DateTime(now.year, now.month);
    for (int i = 0; i < 12; i++) {
      months.add(DateTime(current.year, current.month - i));
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text('Loading dashboard...',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, color: Colors.grey)),
                ],
              ),
            )
          : _error.isNotEmpty
              ? _buildErrorWidget()
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  color: Colors.indigo,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      _buildSliverAppBar(),
                      SliverToBoxAdapter(
                          child:
                              _buildMonthSelector()), // 🚀 Month Selector added here
                      if (_selectedIndex == 0) ..._buildHomeSlivers(),
                      if (_selectedIndex == 1) ..._buildInsightsSlivers(),
                      const SliverPadding(
                          padding: EdgeInsets.only(bottom: 100)),
                    ],
                  ),
                ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddTransaction,
        backgroundColor: Colors.indigo,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // ==========================================
  // VIEW SLIVERS
  // ==========================================

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.indigo,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo.shade900,
                Colors.indigo.shade600,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.8)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userData['name'] ?? 'User',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: Colors.white),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _showNotificationsDialog,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.notifications_outlined,
                                  color: Colors.white, size: 24),
                            ),
                            if (_getUnreadNotificationCount() > 0)
                              Positioned(
                                right: 0,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${_getUnreadNotificationCount()}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              )
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, size: 22),
          onPressed: _logout,
          tooltip: 'Logout',
        ),
        const SizedBox(width: 8)
      ],
    );
  }

  // 🚀 New Widget: Horizontal Month Selector
  Widget _buildMonthSelector() {
    final months = _generateMonthsList();
    return Container(
      height: 60,
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: months.length,
        itemBuilder: (context, index) {
          final month = months[index];
          final isSelected = month.year == _selectedMonth.year &&
              month.month == _selectedMonth.month;
          final String monthStr = DateFormat('MMMM yyyy').format(month);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedMonth = month;
                _filterDataByMonth();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.indigo : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? Colors.indigo : Colors.grey.shade300,
                    width: 1.5),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: Colors.indigo.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3))
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  monthStr,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildHomeSlivers() {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        sliver: SliverToBoxAdapter(child: _buildModernSummaryCards()),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        sliver: SliverToBoxAdapter(child: _buildBudgetWidget()),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        sliver: SliverToBoxAdapter(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Color(0xFF1E293B)),
              ),
              GestureDetector(
                onTap: _showAllTransactionsDialog,
                child: const Text('View All',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                        fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
      _filteredTransactions.isEmpty // 🚀 Uses filtered data
          ? SliverToBoxAdapter(child: _buildEmptyState())
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _filteredTransactions.length) return null;
                  final transaction = _filteredTransactions[index];
                  return _buildTransactionCard(transaction);
                },
                childCount: _filteredTransactions.length > 5
                    ? 5
                    : _filteredTransactions.length,
              ),
            ),
    ];
  }

  List<Widget> _buildInsightsSlivers() {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        sliver: SliverToBoxAdapter(
          child: const Text(
            'Financial Insights',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Color(0xFF1E293B)),
          ),
        ),
      ),
      if (_filteredTransactions.isEmpty) // 🚀 Uses filtered data
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: _buildEmptyState(),
          ),
        )
      else ...[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(child: _buildPieChartCard()),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          sliver: SliverToBoxAdapter(child: _buildBarChartCard()),
        ),
      ]
    ];
  }

  // ==========================================
  // MODERN SUMMARY CARDS
  // ==========================================

  Widget _buildModernSummaryCards() {
    return Column(
      children: [
        // BIG BALANCE CARD
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF1E293B).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Balance: ${DateFormat('MMM yyyy').format(_selectedMonth)}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _userData['currency'] ?? 'BDT',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '৳${_balance.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                'Income',
                '৳${_totalIncome.toStringAsFixed(0)}',
                const Color(0xFF10B981),
                Icons.arrow_downward_rounded,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMiniStatCard(
                'Expenses',
                '৳${_totalExpense.toStringAsFixed(0)}',
                const Color(0xFFEF4444),
                Icons.arrow_upward_rounded,
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildMiniStatCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: const Color(0xFF1E293B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CHARTS IMPLEMENTATION
  // ==========================================

  // 🚀 New: Extract categories locally from filtered transactions
  List<Map<String, dynamic>> _getLocalExpenseCategories() {
    Map<String, double> catMap = {};
    for (var tx in _filteredTransactions) {
      if (tx['type'] == 'Expense') {
        String cat = tx['category'] ?? 'Other';
        catMap[cat] = (catMap[cat] ?? 0) + (tx['amount'] ?? 0).toDouble();
      }
    }
    List<Map<String, dynamic>> res =
        catMap.entries.map((e) => {'_id': e.key, 'expense': e.value}).toList();
    res.sort((a, b) => b['expense'].compareTo(a['expense']));
    return res;
  }

  Widget _buildPieChartCard() {
    final expenseCategories = _getLocalExpenseCategories();

    if (expenseCategories.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Expense Breakdown',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 45,
                      sections: List.generate(expenseCategories.length, (i) {
                        final data = expenseCategories[i];
                        return PieChartSectionData(
                          color: _chartColors[i % _chartColors.length],
                          value: (data['expense'] ?? 0).toDouble(),
                          title:
                              '${((data['expense'] / _totalExpense) * 100).toStringAsFixed(0)}%',
                          radius: 40.0,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        );
                      }),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(expenseCategories.length, (i) {
                      if (i > 4) return const SizedBox.shrink();
                      final data = expenseCategories[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color:
                                        _chartColors[i % _chartColors.length],
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(data['_id'] ?? 'Other',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey),
                                    overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 Modified: Bar chart aggregates data into 5 weeks for the selected month
  Widget _buildBarChartCard() {
    List<Map<String, dynamic>> weeklyData = [
      {'label': 'W1', 'income': 0.0, 'expense': 0.0}, // Days 1-7
      {'label': 'W2', 'income': 0.0, 'expense': 0.0}, // Days 8-14
      {'label': 'W3', 'income': 0.0, 'expense': 0.0}, // Days 15-21
      {'label': 'W4', 'income': 0.0, 'expense': 0.0}, // Days 22-28
      {'label': 'W5', 'income': 0.0, 'expense': 0.0}, // Days 29-End
    ];

    for (var tx in _filteredTransactions) {
      if (tx['date'] == null) continue;
      DateTime date = DateTime.parse(tx['date']).toLocal();
      double amt = (tx['amount'] ?? 0).toDouble();
      int day = date.day;

      int weekIdx = (day <= 7)
          ? 0
          : (day <= 14)
              ? 1
              : (day <= 21)
                  ? 2
                  : (day <= 28)
                      ? 3
                      : 4;

      if (tx['type'] == 'Income') {
        weeklyData[weekIdx]['income'] += amt;
      } else {
        weeklyData[weekIdx]['expense'] += amt;
      }
    }

    double maxY = 0;
    for (var week in weeklyData) {
      if (week['income'] > maxY) maxY = week['income'];
      if (week['expense'] > maxY) maxY = week['expense'];
    }
    if (maxY == 0) maxY = 100;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Weekly Cash Flow',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF1E293B))),
              Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFF10B981), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('In',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                  const SizedBox(width: 12),
                  Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFFEF4444), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Out',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                ],
              )
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text(weeklyData[value.toInt()]['label'],
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 2 == 0 ? 1 : maxY / 2,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1.5),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(5, (i) {
                  return BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                          toY: weeklyData[i]['income'],
                          color: const Color(0xFF10B981),
                          width: 10,
                          borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(
                          toY: weeklyData[i]['expense'],
                          color: const Color(0xFFEF4444),
                          width: 10,
                          borderRadius: BorderRadius.circular(4)),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGETS
  // ==========================================

  Widget _buildBudgetWidget() {
    double progress = 0.0;
    if (_monthlyBudget > 0) {
      progress = _totalExpense / _monthlyBudget;
      if (progress > 1.0) progress = 1.0;
    }

    Color progressColor = const Color(0xFF10B981); // Green
    if (progress > 0.75) progressColor = const Color(0xFFF59E0B); // Orange
    if (progress > 0.90) progressColor = const Color(0xFFEF4444); // Red

    return GestureDetector(
      onTap: _showBudgetDialog,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: _monthlyBudget == 0
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(16)),
                    child:
                        const Icon(Icons.track_changes, color: Colors.indigo),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Set Monthly Budget',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF1E293B))),
                        SizedBox(height: 4),
                        Text('Enable proactive AI alerts',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.track_changes,
                                color: Colors.indigo, size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Text('Monthly Budget',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF1E293B))),
                        ],
                      ),
                      Row(
                        children: [
                          Text('৳${_monthlyBudget.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.indigo)),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_rounded,
                              size: 16, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Spent: ৳${_totalExpense.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      Text(
                        'Remaining: ৳${(_monthlyBudget - _totalExpense).toStringAsFixed(0)}',
                        style: TextStyle(
                          color: (_monthlyBudget - _totalExpense) < 0
                              ? Colors.red
                              : Colors.indigo,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child:
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
            ),
            const SizedBox(height: 24),
            const Text('Oops! Something went wrong',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 12),
            Text(_error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Retry',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(dynamic transaction) {
    final amount = (transaction['amount'] ?? 0).toDouble();
    final isIncome = transaction['type'] == 'Income';
    final color = isIncome ? const Color(0xFF10B981) : const Color(0xFF1E293B);
    final icon = isIncome ? Icons.arrow_downward : Icons.arrow_upward;
    final date = transaction['date'] != null
        ? DateFormat('MMM dd, yyyy')
            .format(DateTime.parse(transaction['date']).toLocal())
        : '';
    final id = transaction['_id'] ?? transaction.hashCode.toString();

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_sweep_rounded,
            color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Delete Transaction',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text(
                'Are you sure you want to delete this transaction permanently?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        _deleteTransaction(id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showTransactionDetails(transaction),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: isIncome
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16)),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction['category'] ?? 'Transaction',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isIncome ? '+' : '-'}৳${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                        fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.indigo.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_rounded,
                size: 50, color: Colors.indigo),
          ),
          const SizedBox(height: 24),
          const Text('No Transactions Yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          const Text('You don\'t have any transactions for the selected month.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTap,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        items: const [
          BottomNavigationBarItem(
              icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.dashboard_rounded)),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.pie_chart_rounded)),
              label: 'Insights'),
          BottomNavigationBarItem(
              icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.auto_awesome)),
              label: 'AI Chat'),
          BottomNavigationBarItem(
              icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.person_outline_rounded)),
              label: 'Profile'),
        ],
      ),
    );
  }

  void _showTransactionDetails(dynamic transaction) {
    final amount = (transaction['amount'] ?? 0).toDouble();
    final isIncome = transaction['type'] == 'Income';
    final date = transaction['date'] != null
        ? DateFormat('EEEE, MMMM dd, yyyy hh:mm a')
            .format(DateTime.parse(transaction['date']).toLocal())
        : '';
    final id = transaction['_id'] ?? transaction.hashCode.toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: (isIncome ? Colors.green : Colors.red)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Icon(
                    isIncome
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: isIncome ? Colors.green : Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transaction['category'] ?? 'Transaction',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      Text(
                        transaction['type'] ?? '',
                        style: TextStyle(
                            color: isIncome ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isIncome ? '+' : '-'}৳${amount.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: isIncome ? Colors.green : const Color(0xFF1E293B)),
                ),
              ],
            ),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(height: 1)),
            _buildDetailRow('Description',
                transaction['description'] ?? 'No description provided'),
            const SizedBox(height: 20),
            _buildDetailRow('Date', date),
            const SizedBox(height: 20),
            _buildDetailRow('Category', transaction['category'] ?? ''),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300, width: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Close',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteTransaction(id);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Delete',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B))),
        ),
      ],
    );
  }

  void _showNotificationsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 32),
            const Text('Notifications',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 20),
            Expanded(
              child: _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No new notifications',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  : StatefulBuilder(builder:
                      (BuildContext context, StateSetter setModalState) {
                      return ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final isUnread = notification['status'] == 'unread';
                          final String notificationId =
                              notification['_id'] ?? index.toString();

                          final String dynamicMessage =
                              _formatNotificationMessage(
                                  notification['message'] ?? '');
                          final String bdTimeText =
                              _formatToBDTime(notification['created_at']);

                          return Dismissible(
                            key: Key(notificationId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.white, size: 28),
                            ),
                            onDismissed: (direction) {
                              setModalState(() {
                                _notifications.removeAt(index);
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: isUnread
                                    ? Colors.indigo.shade50
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: isUnread
                                        ? Colors.indigo.shade100
                                        : Colors.grey.shade100),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(20),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: isUnread
                                          ? Colors.indigo
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(16)),
                                  child: Icon(
                                    Icons.notifications_active_rounded,
                                    color: isUnread
                                        ? Colors.white
                                        : Colors.grey.shade400,
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      notification['title'] ?? 'Alert',
                                      style: TextStyle(
                                          fontWeight: isUnread
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          fontSize: 16,
                                          color: const Color(0xFF1E293B)),
                                    ),
                                    if (bdTimeText.isNotEmpty)
                                      Text(
                                        bdTimeText,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey),
                                      ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    dynamicMessage,
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                                trailing: isUnread
                                    ? Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                            color: Color(0xFFEF4444),
                                            shape: BoxShape.circle))
                                    : null,
                                onTap: () async {
                                  if (isUnread) {
                                    await ApiService().markNotificationRead(
                                        notification['_id']);
                                    _refreshData();
                                    Navigator.pop(context);
                                    _showNotificationsDialog();
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      );
                    }),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllTransactionsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.90,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Center(
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text(
                  'All Transactions (${DateFormat('MMM yyyy').format(_selectedMonth)})',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B))),
            ),
            Expanded(
              child: _filteredTransactions.isEmpty // 🚀 Uses filtered data
                  ? const Center(
                      child: Text('No transactions found',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _filteredTransactions.length,
                      itemBuilder: (context, index) {
                        return _buildTransactionCard(
                            _filteredTransactions[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
