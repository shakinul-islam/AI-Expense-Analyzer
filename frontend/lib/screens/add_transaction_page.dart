import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _smartEntryController = TextEditingController();

  String _selectedType = 'Expense';
  String _selectedCategory = 'Food';
  bool _isLoading = false;
  bool _isClassifying = false;
  bool _isExtracting = false;

  // Selection mode for deleting custom categories
  bool _categoryManageMode = false;
  final Set<String> _selectedCategories = {};

  final List<String> _defaultCategories = [
    'Food',
    'Transport',
    'Shopping',
    'Entertainment',
    'Bills',
    'Health',
    'Education',
    'Salary',
    'Investment',
    'Other',
  ];

  List<String> _customCategories = [];

  List<String> get _allCategories =>
      [..._defaultCategories, ..._customCategories];

  final Map<String, IconData> _categoryIcons = {
    'Food': Icons.restaurant,
    'Transport': Icons.directions_car,
    'Shopping': Icons.shopping_bag,
    'Entertainment': Icons.movie,
    'Bills': Icons.receipt,
    'Health': Icons.health_and_safety,
    'Education': Icons.school,
    'Salary': Icons.attach_money,
    'Investment': Icons.trending_up,
    'Other': Icons.more_horiz,
  };

  final Map<String, Color> _categoryColors = {
    'Food': Colors.orange,
    'Transport': Colors.blue,
    'Shopping': Colors.purple,
    'Entertainment': Colors.red,
    'Bills': Colors.teal,
    'Health': Colors.green,
    'Education': Colors.indigo,
    'Salary': Colors.green,
    'Investment': Colors.amber,
    'Other': Colors.grey,
  };

  final List<Color> _customPalette = [
    Colors.pink,
    Colors.cyan,
    Colors.deepOrange,
    Colors.lightBlue,
    Colors.lime,
    Colors.deepPurple,
    Colors.brown,
    Colors.blueGrey,
  ];

  IconData _iconForCategory(String category) =>
      _categoryIcons[category] ?? Icons.category;

  Color _colorForCategory(String category) {
    if (_categoryColors.containsKey(category)) {
      return _categoryColors[category]!;
    }
    final idx = category.codeUnits.fold<int>(0, (a, b) => a + b) %
        _customPalette.length;
    return _customPalette[idx];
  }

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
  }

  Future<void> _loadCustomCategories() async {
    final cats = await ApiService().getCustomCategories();
    if (mounted) setState(() => _customCategories = cats);
  }

  // 🚀 Add custom category dialog
  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Add Custom Category',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create your own category. It will be saved to your account.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 30,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g., Gym, Pet Care, Coffee',
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a category name';
                    }
                    if (value.trim().length > 30) {
                      return 'Max 30 characters';
                    }
                    final lower = value.trim().toLowerCase();
                    if (_allCategories.any((c) => c.toLowerCase() == lower)) {
                      return 'Category already exists';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!dialogFormKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        final updated = await ApiService()
                            .addCustomCategory(controller.text.trim());
                        if (mounted) {
                          setState(() {
                            _customCategories = updated;
                            _selectedCategory = controller.text.trim();
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '✅ Category "${controller.text.trim()}" added!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '❌ ${e.toString().replaceAll('Exception:', '')}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Add',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 Toggle manage mode for categories
  void _toggleCategoryManageMode() {
    setState(() {
      _categoryManageMode = !_categoryManageMode;
      _selectedCategories.clear();
    });
  }

  void _toggleCategorySelection(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  void _selectAllCustomCategories() {
    setState(() {
      if (_selectedCategories.length == _customCategories.length) {
        _selectedCategories.clear();
      } else {
        _selectedCategories
          ..clear()
          ..addAll(_customCategories);
      }
    });
  }

  // 🚀 Single delete of a custom category
  Future<void> _deleteSingleCategory(String category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "$category"?'),
        content: const Text(
            'Existing transactions will keep this category. This only removes it from the selector.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final updated = await ApiService().deleteCustomCategory(category);
      if (mounted) {
        setState(() {
          _customCategories = updated;
          _selectedCategories.remove(category);
          if (_selectedCategory == category) _selectedCategory = 'Other';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Category "$category" removed'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('❌ ${e.toString().replaceAll('Exception:', '')}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🚀 Bulk delete selected custom categories
  Future<void> _deleteSelectedCategories() async {
    if (_selectedCategories.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${_selectedCategories.length} categories?'),
        content: const Text(
            'This will remove them from your selector. Existing transactions are unaffected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final toDelete = _selectedCategories.toList();
    int deleted = 0;
    for (final cat in toDelete) {
      try {
        final updated = await ApiService().deleteCustomCategory(cat);
        if (mounted) {
          setState(() => _customCategories = updated);
        }
        deleted++;
      } catch (_) {
        // skip on failure
      }
    }
    if (mounted) {
      setState(() {
        _selectedCategories.clear();
        _categoryManageMode = false;
        if (!_customCategories.contains(_selectedCategory)) {
          _selectedCategory = 'Other';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$deleted categor(ies) deleted'),
            backgroundColor: Colors.green),
      );
    }
  }

  void _processSmartEntry() async {
    final text = _smartEntryController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isExtracting = true);
    FocusScope.of(context).unfocus();

    final result = await ApiService().extractExpense(text);

    if (mounted) {
      setState(() {
        _isExtracting = false;
        if (result != null) {
          _amountController.text = result['amount']?.toString() ?? '';
          _descriptionController.text = result['description'] ?? '';

          final detectedCat = result['category']?.toString();
          if (detectedCat != null && _allCategories.contains(detectedCat)) {
            _selectedCategory = detectedCat;
          } else {
            _selectedCategory = 'Other';
          }

          if (_selectedCategory == 'Salary' ||
              _selectedCategory == 'Investment') {
            _selectedType = 'Income';
          } else {
            _selectedType = 'Expense';
          }
        }
      });

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✨ Magic Fill applied! Review and save.'),
              backgroundColor: Colors.indigo),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  '❌ Could not extract details. Please fill manually.'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  void _autoClassifyCategory() async {
    final text = _descriptionController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a description first!'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isClassifying = true);
    final predictedCategory = await ApiService().autoClassify(text);

    if (mounted) {
      setState(() {
        _isClassifying = false;
        _selectedCategory = _allCategories.contains(predictedCategory)
            ? predictedCategory
            : 'Other';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('✨ AI selected: $predictedCategory'),
            backgroundColor: Colors.indigo,
            duration: const Duration(seconds: 2)),
      );
    }
  }

  void _submitTransaction() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await ApiService().addTransaction({
          'amount': double.parse(_amountController.text),
          'type': _selectedType,
          'category': _selectedCategory,
          'description': _descriptionController.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Transaction added successfully!'),
                backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('❌ ${e.toString().replaceAll('Exception:', '')}'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Add Transaction',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Smart AI Entry
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.indigo.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.amberAccent),
                      SizedBox(width: 8),
                      Text('Smart AI Entry',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _smartEntryController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'e.g., Ate KFC burger for 500 tk',
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.6)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _isExtracting ? null : _processSmartEntry,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                              color: Colors.amber, shape: BoxShape.circle),
                          child: _isExtracting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Manual Details',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const SizedBox(height: 24),

                        // Type toggle
                        Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade100),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _selectedType = 'Expense'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _selectedType == 'Expense'
                                          ? Colors.red
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: _selectedType == 'Expense'
                                          ? [
                                              BoxShadow(
                                                  color: Colors.red
                                                      .withOpacity(0.2),
                                                  blurRadius: 4)
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                        child: Text('Expense',
                                            style: TextStyle(
                                                color: _selectedType ==
                                                        'Expense'
                                                    ? Colors.white
                                                    : Colors.grey.shade700,
                                                fontWeight:
                                                    FontWeight.bold))),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _selectedType = 'Income'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _selectedType == 'Income'
                                          ? Colors.green
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: _selectedType == 'Income'
                                          ? [
                                              BoxShadow(
                                                  color: Colors.green
                                                      .withOpacity(0.2),
                                                  blurRadius: 4)
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                        child: Text('Income',
                                            style: TextStyle(
                                                color:
                                                    _selectedType == 'Income'
                                                        ? Colors.white
                                                        : Colors.grey
                                                            .shade700,
                                                fontWeight:
                                                    FontWeight.bold))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Amount
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            prefixIcon: const Icon(Icons.currency_rupee,
                                color: Colors.indigo),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Enter an amount';
                            if (double.tryParse(value) == null)
                              return 'Enter a valid number';
                            if (double.parse(value) <= 0)
                              return 'Amount must be greater than 0';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Description (Optional)',
                            prefixIcon: const Icon(
                                Icons.description_outlined,
                                color: Colors.indigo),
                            suffixIcon: IconButton(
                              icon: _isClassifying
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.auto_awesome,
                                      color: Colors.amber),
                              onPressed: _isClassifying
                                  ? null
                                  : _autoClassifyCategory,
                              tooltip: 'Auto-detect category',
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Category section header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('Category',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87)),
                                if (_categoryManageMode) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Text(
                                      '${_selectedCategories.length} selected',
                                      style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (_customCategories.isNotEmpty)
                              TextButton.icon(
                                onPressed: _toggleCategoryManageMode,
                                icon: Icon(
                                  _categoryManageMode
                                      ? Icons.close
                                      : Icons.edit_outlined,
                                  size: 16,
                                  color: _categoryManageMode
                                      ? Colors.red
                                      : Colors.grey.shade700,
                                ),
                                label: Text(
                                  _categoryManageMode ? 'Done' : 'Manage',
                                  style: TextStyle(
                                      color: _categoryManageMode
                                          ? Colors.red
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                              )
                            else
                              TextButton.icon(
                                onPressed: _showAddCategoryDialog,
                                icon: const Icon(Icons.add,
                                    size: 18, color: Colors.indigo),
                                label: const Text('Add Custom',
                                    style: TextStyle(
                                        color: Colors.indigo,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Manage mode action bar
                        if (_categoryManageMode) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedCategories.isEmpty
                                        ? 'Tap categories to select'
                                        : '${_selectedCategories.length} of ${_customCategories.length} selected',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _selectAllCustomCategories,
                                  child: Text(
                                    _selectedCategories.length ==
                                            _customCategories.length
                                        ? 'Deselect All'
                                        : 'Select All',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton.icon(
                                  onPressed: _selectedCategories.isEmpty
                                      ? null
                                      : _deleteSelectedCategories,
                                  icon: const Icon(Icons.delete_forever,
                                      size: 16, color: Colors.white),
                                  label: const Text('Delete',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Default categories grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: _defaultCategories.length,
                          itemBuilder: (context, index) {
                            return _buildCategoryTile(
                                _defaultCategories[index],
                                isCustom: false);
                          },
                        ),

                        // Custom categories
                        if (_customCategories.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Text('Your Custom Categories',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.indigo)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text('${_customCategories.length}',
                                    style: const TextStyle(
                                        color: Colors.indigo,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: _customCategories.length,
                            itemBuilder: (context, index) {
                              return _buildCategoryTile(
                                  _customCategories[index],
                                  isCustom: true);
                            },
                          ),
                          const SizedBox(height: 8),
                          // Bottom Add button when there are custom categories
                          if (!_categoryManageMode)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _showAddCategoryDialog,
                                icon: const Icon(Icons.add,
                                    size: 18, color: Colors.indigo),
                                label: const Text('Add another category',
                                    style: TextStyle(
                                        color: Colors.indigo,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ),
                            ),
                        ],

                        const SizedBox(height: 32),

                        // Submit
                        SizedBox(
                          height: 55,
                          child: ElevatedButton(
                            onPressed:
                                _isLoading ? null : _submitTransaction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white))
                                : const Text('Save Transaction',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 Category tile — supports selection mode + single delete (long-press on custom)
  Widget _buildCategoryTile(String category, {required bool isCustom}) {
    final isSelected = _selectedCategory == category;
    final isMarked = _selectedCategories.contains(category);
    final showMark = isCustom && _categoryManageMode;
    final color = _colorForCategory(category);
    final icon = _iconForCategory(category);

    // In manage mode, custom tile is highlighted if MARKED; otherwise by selection
    final highlight = showMark ? isMarked : isSelected;
    final highlightColor = showMark ? Colors.red : color;

    return GestureDetector(
      onTap: () {
        if (showMark) {
          _toggleCategorySelection(category);
        } else {
          setState(() => _selectedCategory = category);
        }
      },
      onLongPress: isCustom && !_categoryManageMode
          ? () => _deleteSingleCategory(category)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: highlight ? highlightColor : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: highlight ? highlightColor : Colors.grey.shade200),
          boxShadow: highlight
              ? [
                  BoxShadow(
                      color: highlightColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: highlight ? Colors.white : color, size: 24),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    category,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: highlight
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color:
                            highlight ? Colors.white : Colors.black87),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Custom star badge
            if (isCustom && !showMark)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.3)
                        : Colors.indigo.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.star,
                      size: 8,
                      color: isSelected ? Colors.white : Colors.indigo),
                ),
              ),
            // Selection checkmark
            if (showMark)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isMarked ? Colors.white : Colors.white70,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                      isMarked
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 14,
                      color: isMarked ? Colors.red : Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _smartEntryController.dispose();
    super.dispose();
  }
}