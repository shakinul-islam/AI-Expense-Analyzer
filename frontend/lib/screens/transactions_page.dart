import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/currency_helper.dart';

class TransactionsPage extends StatefulWidget {
  final String currency;
  const TransactionsPage({super.key, this.currency = 'BDT'});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  String _error = '';

  // Selection mode (for bulk delete)
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Debounce: 500ms delay after typing to prevent API spam
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final tx = await ApiService().searchTransactions(
        search: _searchController.text,
      );

      if (!mounted) return;
      setState(() {
        _transactions = tx;
        _selectedIds.removeWhere((id) => !tx.any((t) => t['_id'] == id));
        if (_selectedIds.isEmpty) _selectionMode = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception:', '').trim();
        _transactions = [];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🚀 Single Delete
  Future<void> _deleteSingle(String id) async {
    try {
      await ApiService().deleteTransaction(id);
      if (mounted) {
        setState(() {
          _transactions.removeWhere((t) => t['_id'] == id);
          _selectedIds.remove(id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🚀 Bulk Delete (Mark & Delete)
  Future<void> _deleteBulk() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Selected?'),
        content: Text('Delete ${_selectedIds.length} transaction(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService().bulkDeleteTransactions(_selectedIds.toList());
      if (mounted) {
        setState(() {
          _transactions.removeWhere((t) => _selectedIds.contains(t['_id']));
          _selectedIds.clear();
          _selectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected transactions deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Selection Logic
  void _enterSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      final allIds = _transactions.map((t) => t['_id']).whereType<String>().toSet();
      if (_selectedIds.length == allIds.length && allIds.isNotEmpty) {
        _selectedIds.clear();
        _selectionMode = false;
      } else {
        _selectedIds..clear()..addAll(allIds);
        _selectionMode = allIds.isNotEmpty;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_selectionMode) {
      final allIds = _transactions.map((t) => t['_id']).whereType<String>().toSet();
      final allSelected = _selectedIds.length == allIds.length && allIds.isNotEmpty;

      return AppBar(
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelection,
        ),
        title: Text('${_selectedIds.length} selected'),
        actions: [
          IconButton(
            icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
            onPressed: _selectAll,
            tooltip: 'Select All',
          ),
          // 🚀 Delete Icon in Top Bar
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            onPressed: _selectedIds.isEmpty ? null : _deleteBulk,
            tooltip: 'Delete Selected',
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.indigo,
      foregroundColor: Colors.white,
      title: const Text('Transactions'),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by description or category...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadData();
                  })
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.indigo));
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No results for "${_searchController.text}"'
                  : 'No transactions found',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      itemBuilder: (c, i) {
        final t = _transactions[i];
        final id = t['_id'] as String?;
        final isSelected = id != null && _selectedIds.contains(id);
        return _buildRow(t, isSelected);
      },
    );
  }

  Widget _buildRow(dynamic t, bool isSelected) {
    final id = t['_id'] as String?;
    final isIncome = t['type'] == 'Income';
    final amount = (t['amount'] ?? 0).toDouble();
    final date = t['date'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(t['date']).toLocal())
        : '';

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isSelected ? Colors.red : Colors.grey.shade200,
            width: isSelected ? 2 : 1),
      ),
      child: Row(
        children: [
          if (_selectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? Colors.red : Colors.grey,
              ),
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isIncome ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['category'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                if ((t['description'] ?? '').toString().isNotEmpty)
                  Text(t['description'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text(date, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${CurrencyHelper.format(amount, widget.currency)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.red),
          ),
        ],
      ),
    );

    // If in selection mode, tap toggles checkbox
    if (_selectionMode) {
      return GestureDetector(
        onTap: () => id != null ? _toggleSelection(id) : null,
        child: Padding(padding: const EdgeInsets.only(bottom: 10), child: card),
      );
    }

    // If NOT in selection mode: Swipe to delete, Long-press to select
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(id ?? t.hashCode.toString()),
        direction: DismissDirection.endToStart, // Swipe from right to left
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.delete, color: Colors.white),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Delete Transaction?'),
              content: const Text('Are you sure you want to delete this permanently?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(c, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) => id != null ? _deleteSingle(id) : null,
        child: GestureDetector(
          onLongPress: () => id != null ? _enterSelection(id) : null, // 🚀 Long Press to Select
          child: card,
        ),
      ),
    );
  }
}