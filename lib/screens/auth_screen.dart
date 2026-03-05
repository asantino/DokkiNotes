import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await AuthService.instance.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await AuthService.instance.signUp(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.instance.isAuthenticated) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          backgroundColor: Colors.grey[900],
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_circle,
                size: 100,
                color: Color(0xFF00BCD4),
              ),
              const SizedBox(height: 24),
              Text(
                AuthService.instance.currentUserEmail ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 60),
              IconButton(
                iconSize: 48,
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                onPressed: () async {
                  await AuthService.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Center(
              child: Icon(
                Icons.account_circle,
                size: 100,
                color: Color(0xFF00BCD4),
              ),
            ),
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.email, color: Color(0xFF00BCD4), size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF00BCD4)),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Color(0xFF00BCD4), size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF00BCD4)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            Center(
              child: FloatingActionButton(
                onPressed: _isLoading ? null : _handleAuth,
                backgroundColor: const Color(0xFF00BCD4),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3),
                      )
                    : const Icon(Icons.arrow_forward_ios, color: Colors.white),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.login),
                    color:
                        _isLogin ? const Color(0xFF00BCD4) : Colors.grey[600],
                    onPressed: () => setState(() {
                      _isLogin = true;
                    }),
                  ),
                  const SizedBox(width: 40),
                  IconButton(
                    icon: const Icon(Icons.person_add),
                    color:
                        !_isLogin ? const Color(0xFF00BCD4) : Colors.grey[600],
                    onPressed: () => setState(() {
                      _isLogin = false;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Icon(Icons.error, color: Colors.redAccent, size: 24),
              ),
          ],
        ),
      ),
    );
  }
}
