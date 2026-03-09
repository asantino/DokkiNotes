import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet>
    with SingleTickerProviderStateMixin {
  int _step = 0; // 0=old, 1=new, 2=confirm
  bool _isLoading = false;

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _oldFocusNode = FocusNode();
  final _newFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  final List<IconData> _stepIcons = [
    Icons.lock_outline, // Шаг 0: старый пароль
    Icons.edit_outlined, // Шаг 1: новый пароль
    Icons.check_circle_outline, // Шаг 2: подтверждение
  ];

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _oldFocusNode.dispose();
    _newFocusNode.dispose();
    _confirmFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _shakeAndClear() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0);
    if (_step == 0) _oldPasswordController.clear();
    if (_step == 1) _newPasswordController.clear();
    if (_step == 2) _confirmPasswordController.clear();
  }

  Future<void> _onComplete() async {
    setState(() => _isLoading = true);

    try {
      if (_step == 0) {
        // Шаг 0: Проверка старого пароля
        final email = AuthService.instance.currentUserEmail;
        if (email != null) {
          await AuthService.instance.signIn(email, _oldPasswordController.text);
          setState(() => _step = 1);
          _newFocusNode.requestFocus();
        } else {
          _shakeAndClear();
        }
      } else if (_step == 1) {
        // Шаг 1: Ввод нового пароля
        if (_newPasswordController.text.length < 6) {
          _shakeAndClear();
        } else {
          setState(() => _step = 2);
          _confirmFocusNode.requestFocus();
        }
      } else if (_step == 2) {
        // Шаг 2: Подтверждение нового пароля
        if (_newPasswordController.text == _confirmPasswordController.text) {
          await AuthService.instance
              .changePassword(_newPasswordController.text);
          if (mounted) Navigator.pop(context, true);
        } else {
          _shakeAndClear();
        }
      }
    } catch (e) {
      _shakeAndClear();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),
              Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: Icon(
                  _stepIcons[_step],
                  size: 48,
                  color: const Color(0xFF00BCD4),
                ),
              ),
              const SizedBox(height: 32),
              _buildStepField(),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator(color: Color(0xFF00BCD4))
              else
                IconButton(
                  iconSize: 48,
                  icon:
                      const Icon(Icons.check_circle, color: Color(0xFF00BCD4)),
                  onPressed: _onComplete,
                ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepField() {
    if (_step == 0) {
      return _buildTextField(_oldPasswordController, _oldFocusNode);
    } else if (_step == 1) {
      return _buildTextField(_newPasswordController, _newFocusNode);
    } else {
      return _buildTextField(_confirmPasswordController, _confirmFocusNode);
    }
  }

  Widget _buildTextField(
      TextEditingController controller, FocusNode focusNode) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: true,
      autofocus: true,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      textAlign: TextAlign.center,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _onComplete(),
      decoration: InputDecoration(
        enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[700]!)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF00BCD4))),
      ),
    );
  }
}
