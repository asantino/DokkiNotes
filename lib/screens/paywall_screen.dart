import 'package:flutter/material.dart';
import '../services/railway_service.dart';
import '../services/auth_service.dart';
import '../services/purchase_service.dart';
import '../widgets/ai_mic_icon.dart';
import 'auth_screen.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = true;
  int _balance = 0;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await PurchaseService.instance.initialize();
    await _loadBalance();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBalance() async {
    debugPrint('🔍 isAuthenticated: ${AuthService.instance.isAuthenticated}');
    if (AuthService.instance.isAuthenticated) {
      try {
        final balance = await RailwayService.instance.checkBalance();
        debugPrint('🔍 balance: $balance');
        if (mounted) {
          setState(() {
            _balance = balance;
          });
        }
      } catch (e) {
        debugPrint('🔍 error loading balance: $e');
      }
    }
  }

  Future<void> _goToAuth() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
    if (!mounted) return;
    await _loadBalance();
  }

  Future<void> _purchase(String productId) async {
    if (!AuthService.instance.isAuthenticated) {
      _goToAuth();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final product = PurchaseService.instance.getProduct(productId);
      if (product == null) return;
      await PurchaseService.instance.buyTokens(product);
      await _loadBalance();
    } catch (e) {
      debugPrint('Purchase error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPackageRow({
    required IconData icon,
    required Color color,
    required String amount,
    required String price,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Text(
              amount,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              price,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuth = AuthService.instance.isAuthenticated;

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAuth)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  const AiMicIcon(size: 28, color: Color(0xFFFFD700)),
                  const SizedBox(width: 16),
                  Text(
                    '$_balance',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  _buildPackageRow(
                    icon: Icons.stars,
                    color: Colors.blueGrey[300]!,
                    amount: '100',
                    price: '\$0.99',
                    onTap: () => _purchase(PurchaseService.token100Id),
                  ),
                  const SizedBox(height: 8),
                  _buildPackageRow(
                    icon: Icons.stars,
                    color: const Color(0xFF00BCD4),
                    amount: '500',
                    price: '\$4.49',
                    onTap: () => _purchase(PurchaseService.token500Id),
                  ),
                  const SizedBox(height: 8),
                  _buildPackageRow(
                    icon: Icons.stars,
                    color: const Color(0xFFFFD700),
                    amount: '1000',
                    price: '\$7.99',
                    onTap: () => _purchase(PurchaseService.token1000Id),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
