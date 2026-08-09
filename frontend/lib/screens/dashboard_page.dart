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
  List<dynamic> _summary = [];
  Map<String, dynamic> _userData = {};
  List<dynamic> _notifications = [];
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _error = '';
  String _selectedPeriod = 'This Month';
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _balance = 0;
  double _monthlyBudget = 0;

  final List<String> _periods = [
    'Today',
    'This Week',
    'This Month',
    'This Year'
  ];

  final List<Color> _chartColors = [
    Colors.orange,
    Colors.blue,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.amber
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
      await _loadSummary();
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
        _calculateTotals();
      });
    } catch (e) {
      throw Exception('Failed to load transactions');
    }
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await ApiService().getSummary();
      setState(() {
        _summary = summary;
      });
    } catch (e) {
      // Summary is optional
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
        final List<dynamic> budgets = jsonDecode(response.body);
        final now = DateTime.now();

        final currentBudgets = budgets
            .cast<Map<String, dynamic>>()
            .where((b) => b['month'] == now.month && b['year'] == now.year)
            .toList();

        setState(() {
          if (currentBudgets.isNotEmpty) {
            _monthlyBudget =
                (currentBudgets.last['monthly_limit'] ?? 0).toDouble();
          } else {
            _monthlyBudget = 0;
          }
        });
      }
    } catch (e) {
      print('Load budget error: $e');
    }
  }

  Future<void> _saveBudget(double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final now = DateTime.now();

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/budgets'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'monthly_limit': amount,
          'month': now.month,
          'year': now.year,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() {
          _monthlyBudget = amount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(amount == 0
                ? 'Budget removed'
                : 'Budget updated successfully!'),
            backgroundColor: amount == 0 ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to update budget'),
            backgroundColor: Colors.red),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Monthly Budget',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set a limit for your expenses this month to receive proactive AI alerts.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: budgetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Budget Amount',
                prefixText: '৳ ',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(budgetController.text) ?? 0;
              Navigator.pop(context);
              _saveBudget(amount);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
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
      _calculateTotals();
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
          const SnackBar(
              content: Text('Transaction deleted successfully'),
              backgroundColor: Colors.green),
        );
        _loadSummary();
      }
    } catch (e) {
      print('Delete error: $e');
    }
  }

  void _calculateTotals() {
    _totalIncome = 0;
    _totalExpense = 0;

    for (var transaction in _transactions) {
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
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ApiService().logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
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
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        break;
      case 1:
        _navigateToAddTransaction();
        break;
      case 2:
        _navigateToAiChat();
        break;
      case 3:
        _navigateToProfile();
        break;
    }
  }

  int _getUnreadNotificationCount() {
    return _notifications.where((n) => n['status'] == 'unread').length;
  }

  // 🚀 BD Time Formatter
  String _formatToBDTime(String? dateString) {
    if (dateString == null) return '';
    try {
      DateTime parsedUTC = DateTime.parse(dateString).toUtc();
      DateTime bdTime = parsedUTC.add(const Duration(hours: 6)); // UTC + 6
      return DateFormat('MMM dd, yyyy - hh:mm a').format(bdTime);
    } catch (e) {
      return '';
    }
  }

  // 🚀 Dynamic Budget Text Formatter
  String _formatNotificationMessage(String originalMsg) {
    if (_monthlyBudget > 0 && originalMsg.contains('budget of')) {
      // Replace the hardcoded budget number with the current dynamic budget
      return originalMsg.replaceAll(RegExp(r'budget of ৳[0-9]+'),
          'budget of ৳${_monthlyBudget.toStringAsFixed(0)}');
    }
    return originalMsg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text('Loading dashboard...',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            )
          : _error.isNotEmpty
              ? _buildErrorWidget()
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  color: Colors.indigo,
                  child: CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 160,
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
                                  Colors.indigo.shade800,
                                  Colors.purple.shade700
                                ],
                              ),
                            ),
                            child: SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back! 👋',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white.withOpacity(0.9)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _userData['name'] ?? 'User',
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 6),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.attach_money,
                                                  size: 16,
                                                  color: Colors.white),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${_userData['currency'] ?? 'BDT'}',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                          onTap: _showNotificationsDialog,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                    Icons.notifications_active,
                                                    size: 16,
                                                    color: Colors.amberAccent),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${_getUnreadNotificationCount()} New',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.logout),
                            onPressed: _logout,
                            tooltip: 'Logout',
                          ),
                        ],
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        sliver: SliverToBoxAdapter(child: _buildBudgetWidget()),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(child: _buildSummaryCards()),
                      ),
                      if (_transactions.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Financial Insights',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                ),
                                const SizedBox(height: 12),
                                _buildPieChartCard(), // Expense Breakdown
                                const SizedBox(height: 16),
                                _buildBarChartCard(), // Cash Flow
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent Transactions',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                              TextButton(
                                onPressed: _showAllTransactionsDialog,
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.indigo),
                                child: const Text('View All',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _transactions.isEmpty
                          ? SliverToBoxAdapter(child: _buildEmptyState())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index >= _transactions.length)
                                    return null;
                                  final transaction = _transactions[index];
                                  return _buildTransactionCard(transaction);
                                },
                                childCount: _transactions.length > 5
                                    ? 5
                                    : _transactions.length,
                              ),
                            ),
                      const SliverPadding(
                          padding: EdgeInsets.only(bottom: 100)),
                    ],
                  ),
                ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddTransaction,
        backgroundColor: Colors.indigo,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // ==========================================
  // 📈 CHARTS IMPLEMENTATION
  // ==========================================

  Widget _buildPieChartCard() {
    final expenseCategories =
        _summary.where((s) => (s['expense'] ?? 0) > 0).toList();

    if (expenseCategories.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Expense Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: List.generate(expenseCategories.length, (i) {
                        final data = expenseCategories[i];
                        final double fontSize = 12.0;
                        final double radius = 40.0;
                        return PieChartSectionData(
                          color: _chartColors[i % _chartColors.length],
                          value: (data['expense'] ?? 0).toDouble(),
                          title:
                              '${((data['expense'] / _totalExpense) * 100).toStringAsFixed(0)}%',
                          radius: radius,
                          titleStyle: TextStyle(
                              fontSize: fontSize,
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
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    color:
                                        _chartColors[i % _chartColors.length],
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(data['_id'] ?? 'Other',
                                    style: const TextStyle(fontSize: 12),
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

  Widget _buildBarChartCard() {
    final now = DateTime.now();
    List<Map<String, dynamic>> last7Days = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      double dailyInc = 0;
      double dailyExp = 0;

      for (var tx in _transactions) {
        final txDate = DateTime.parse(tx['date']);
        if (txDate.year == date.year &&
            txDate.month == date.month &&
            txDate.day == date.day) {
          final amt = (tx['amount'] ?? 0).toDouble();
          if (tx['type'] == 'Income')
            dailyInc += amt;
          else
            dailyExp += amt;
        }
      }
      last7Days.add({
        'day': DateFormat('E').format(date).substring(0, 3),
        'income': dailyInc,
        'expense': dailyExp
      });
    }

    double maxY = 0;
    for (var day in last7Days) {
      if (day['income'] > maxY) maxY = day['income'];
      if (day['expense'] > maxY) maxY = day['expense'];
    }
    if (maxY == 0) maxY = 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cash Flow (Last 7 Days)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  Container(width: 10, height: 10, color: Colors.green),
                  const SizedBox(width: 4),
                  const Text('In', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 8),
                  Container(width: 10, height: 10, color: Colors.red),
                  const SizedBox(width: 4),
                  const Text('Out', style: TextStyle(fontSize: 10)),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
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
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(last7Days[value.toInt()]['day'],
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        );
                      },
                      reservedSize: 28,
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
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                          toY: last7Days[i]['income'],
                          color: Colors.green,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4))),
                      BarChartRodData(
                          toY: last7Days[i]['expense'],
                          color: Colors.redAccent,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4))),
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

    Color progressColor = Colors.green;
    if (progress > 0.75) progressColor = Colors.orange;
    if (progress > 0.90) progressColor = Colors.red;

    return GestureDetector(
      onTap: _showBudgetDialog,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.indigo.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: _monthlyBudget == 0
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.indigo.shade50, shape: BoxShape.circle),
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
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87)),
                        SizedBox(height: 4),
                        Text('Enable proactive AI alerts',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                          const Icon(Icons.account_balance_wallet,
                              color: Colors.indigo, size: 20),
                          const SizedBox(width: 8),
                          const Text('Monthly Budget',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Row(
                        children: [
                          Text('৳${_monthlyBudget.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.indigo)),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 16, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Spent: ৳${_totalExpense.toStringAsFixed(0)}',
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 13)),
                      Text(
                        'Remaining: ৳${(_monthlyBudget - _totalExpense).toStringAsFixed(0)}',
                        style: TextStyle(
                          color: (_monthlyBudget - _totalExpense) < 0
                              ? Colors.red
                              : Colors.green,
                          fontWeight: FontWeight.bold,
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
              child:
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
            ),
            const SizedBox(height: 24),
            const Text('Oops! Something went wrong',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Balance',
            '৳${_balance.toStringAsFixed(0)}',
            Colors.indigo,
            Icons.account_balance,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Income',
            '৳${_totalIncome.toStringAsFixed(0)}',
            Colors.green,
            Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Expenses',
            '৳${_totalExpense.toStringAsFixed(0)}',
            Colors.red,
            Icons.arrow_upward,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _periods.length,
        itemBuilder: (context, index) {
          final period = _periods[index];
          final isSelected = _selectedPeriod == period;
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = period),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.indigo : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? Colors.indigo : Colors.grey.shade300,
                    width: 1),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: Colors.indigo.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  period,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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

  Widget _buildTransactionCard(dynamic transaction) {
    final amount = (transaction['amount'] ?? 0).toDouble();
    final isIncome = transaction['type'] == 'Income';
    final color = isIncome ? Colors.green : Colors.red;
    final icon = isIncome ? Icons.south_west : Icons.north_east;
    final date = transaction['date'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(transaction['date']))
        : '';
    final id = transaction['_id'] ?? transaction.hashCode.toString();

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_sweep, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Transaction',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text(
                'Are you sure you want to delete this transaction permanently?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showTransactionDetails(transaction),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              title: Text(
                transaction['category'] ?? 'Transaction',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  date,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'}৳${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isIncome ? 'Income' : 'Expense',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500),
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
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1), shape: BoxShape.circle),
            child:
                const Icon(Icons.receipt_long, size: 50, color: Colors.indigo),
          ),
          const SizedBox(height: 16),
          const Text('No Transactions Yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Start tracking your expenses by adding your first transaction.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Transaction',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5)),
        ],
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
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline), label: 'Add'),
          BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome), label: 'AI Insights'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  void _showTransactionDetails(dynamic transaction) {
    final amount = (transaction['amount'] ?? 0).toDouble();
    final isIncome = transaction['type'] == 'Income';
    final date = transaction['date'] != null
        ? DateFormat('EEEE, MMMM dd, yyyy hh:mm a')
            .format(DateTime.parse(transaction['date']))
        : '';
    final id = transaction['_id'] ?? transaction.hashCode.toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: (isIncome ? Colors.green : Colors.red)
                          .withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(
                    isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isIncome ? Colors.green : Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transaction['category'] ?? 'Transaction',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
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
                      fontWeight: FontWeight.bold,
                      color: isIncome ? Colors.green : Colors.red),
                ),
              ],
            ),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
            _buildDetailRow('Description',
                transaction['description'] ?? 'No description provided'),
            const SizedBox(height: 16),
            _buildDetailRow('Date', date),
            const SizedBox(height: 16),
            _buildDetailRow('Category', transaction['category'] ?? ''),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
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
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ),
      ],
    );
  }

  // 🚀 Modified: Swipe to Delete, BD Time format & Dynamic Budget Text implemented
  void _showNotificationsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Notifications',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 50, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No new notifications',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    )
                  : StatefulBuilder(
                      // StatefulBuilder to rebuild this specific bottom sheet context
                      builder:
                          (BuildContext context, StateSetter setModalState) {
                      return ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final isUnread = notification['status'] == 'unread';
                          final String notificationId =
                              notification['_id'] ?? index.toString();

                          // Replace old 1000 with current active budget
                          final String dynamicMessage =
                              _formatNotificationMessage(
                                  notification['message'] ?? '');
                          // Format to BD Time
                          final String bdTimeText =
                              _formatToBDTime(notification['created_at']);

                          return Dismissible(
                            key: Key(notificationId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white, size: 28),
                            ),
                            onDismissed: (direction) {
                              setModalState(() {
                                _notifications.removeAt(index);
                              });
                              // To make this permanent, you need a delete route in your backend!
                              // ApiService().deleteNotification(notificationId);
                            },
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              color: isUnread
                                  ? Colors.indigo.shade50
                                  : Colors.grey.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                    color: isUnread
                                        ? Colors.indigo.shade100
                                        : Colors.transparent),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: isUnread
                                      ? Colors.indigo
                                      : Colors.grey.shade300,
                                  child: Icon(
                                    Icons.notifications_active,
                                    color: isUnread
                                        ? Colors.white
                                        : Colors.grey.shade500,
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
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          fontSize: 16),
                                    ),
                                    if (bdTimeText.isNotEmpty)
                                      Text(
                                        bdTimeText,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade500),
                                      ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    dynamicMessage,
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        height: 1.3),
                                  ),
                                ),
                                trailing: isUnread
                                    ? Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                            color: Colors.redAccent,
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('All Transactions',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: _transactions.isEmpty
                  ? const Center(child: Text('No transactions found'))
                  : ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        return _buildTransactionCard(_transactions[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
