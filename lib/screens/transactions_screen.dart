import 'package:flutter/material.dart';
import '../services/railway_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final transactions = await RailwayService.instance.getTransactions();
    if (mounted) {
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
            )
          : _transactions.isEmpty
              ? Center(
                  child: Icon(Icons.receipt_long,
                      size: 64, color: Colors.grey[600]),
                )
              : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    final amount = tx['amount'] as int? ?? 0;

                    final isPositive = amount > 0;
                    final amountText = isPositive ? '+$amount' : '$amount';

                    return ListTile(
                      leading: Icon(
                        isPositive
                            ? Icons.add_circle_outline
                            : Icons.remove_circle_outline,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                      trailing: Text(
                        amountText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
