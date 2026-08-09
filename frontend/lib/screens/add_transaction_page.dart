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

  final List<String> _categories = [
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

  void _processSmartEntry() async {
    final text = _smartEntryController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isExtracting = true);
    FocusScope.of(context).unfocus();

    final result = await ApiService().extractExpense(text);

    if (mounted) {
      setState(() => _isExtracting = false);
      if (result != null) {
        _amountController.text = result['amount']?.toString() ?? '';
        _descriptionController.text = result['description'] ?? '';

        final detectedCat = result['category']?.toString();
        if (detectedCat != null && _categories.contains(detectedCat)) {
          _selectedCategory = detectedCat;
        } else {
          _selectedCategory = 'Other';
        }

        // Auto select type based on category
        if (_selectedCategory == 'Salary' ||
            _selectedCategory == 'Investment') {
          _selectedType = 'Income';
        } else {
          _selectedType = 'Expense';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✨ Magic Fill applied! Review and save.'),
              backgroundColor: Colors.indigo),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('❌ Could not extract details. Please fill manually.'),
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
        _selectedCategory = predictedCategory;
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
                content: Text('❌ ${e.toString().replaceAll('Exception:', '')}'),
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
            // 🚀 SMART AI ENTRY SECTION
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
                            hintStyle:
                                TextStyle(color: Colors.white.withOpacity(0.6)),
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

            // MANUAL ENTRY FORM
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

                        // Transaction Type
                        Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade100),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedType = 'Expense'),
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
                                                color:
                                                    _selectedType == 'Expense'
                                                        ? Colors.white
                                                        : Colors.grey.shade700,
                                                fontWeight: FontWeight.bold))),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedType = 'Income'),
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
                                                color: _selectedType == 'Income'
                                                    ? Colors.white
                                                    : Colors.grey.shade700,
                                                fontWeight: FontWeight.bold))),
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
                            prefixIcon: const Icon(Icons.description_outlined,
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
                              onPressed:
                                  _isClassifying ? null : _autoClassifyCategory,
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

                        // Category
                        const Text('Category',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87)),
                        const SizedBox(height: 12),
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
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final isSelected = _selectedCategory == category;
                            final color =
                                _categoryColors[category] ?? Colors.grey;

                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = category),
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      isSelected ? color : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: isSelected
                                          ? color
                                          : Colors.grey.shade200),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                              color: color.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2))
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                        _categoryIcons[category] ??
                                            Icons.category,
                                        color:
                                            isSelected ? Colors.white : color,
                                        size: 24),
                                    const SizedBox(height: 6),
                                    Text(
                                      category,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitTransaction,
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
                                        strokeWidth: 2.5, color: Colors.white))
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

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _smartEntryController.dispose();
    super.dispose();
  }
}
