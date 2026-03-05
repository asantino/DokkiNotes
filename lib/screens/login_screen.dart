import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/auth_service.dart';
import '../theme/dokki_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true;
  bool _hasError = false;

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showVisualError();
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      if (_isLogin) {
        await AuthService.instance.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await AuthService.instance.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context, true); // Возвращаем успех
      }
    } catch (e) {
      _showVisualError();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showVisualError() async {
    setState(() => _hasError = true);
    // Иконки мигают красным крестиком на 2 секунды
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _hasError = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Динамические цвета и иконки в зависимости от статуса ошибки
    final activeColor = _hasError ? Colors.redAccent : DokkiColors.primaryTeal;
    final emailIcon =
        _hasError ? CupertinoIcons.xmark_circle : CupertinoIcons.at;
    final passIcon =
        _hasError ? CupertinoIcons.xmark_circle : CupertinoIcons.lock;
    final actionIcon =
        _isLogin ? CupertinoIcons.arrow_right : CupertinoIcons.checkmark_alt;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // --- ПОЛЕ EMAIL ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Row(
                children: [
                  Icon(emailIcon, color: activeColor, size: 28),
                  const SizedBox(width: 24),
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      cursorColor: DokkiColors.primaryTeal,
                    ),
                  ),
                ],
              ),
            ),

            // --- ПОЛЕ ПАРОЛЯ ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Row(
                children: [
                  Icon(passIcon, color: activeColor, size: 28),
                  const SizedBox(width: 24),
                  Expanded(
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      cursorColor: DokkiColors.primaryTeal,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // --- КНОПКА ОТПРАВКИ ---
            GestureDetector(
              onTap: _isLoading ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor,
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? const CupertinoActivityIndicator(
                          color: Colors.white, radius: 14)
                      : Icon(actionIcon, color: Colors.white, size: 32),
                ),
              ),
            ),

            const Spacer(),

            // --- ПЕРЕКЛЮЧАТЕЛЬ ВХОД / РЕГИСТРАЦИЯ ---
            IconButton(
              icon: Icon(
                _isLogin ? CupertinoIcons.person_add : CupertinoIcons.person,
                size: 32,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                  _hasError = false;
                });
              },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
