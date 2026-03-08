import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pin_service.dart';
import '../theme/dokki_theme.dart';

class ChangePinSheet extends StatefulWidget {
  final bool hasExistingPin; // Параметр наличия PIN [cite: 2026-03-08]

  const ChangePinSheet({
    super.key,
    required this.hasExistingPin,
  });

  @override
  State<ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends State<ChangePinSheet>
    with SingleTickerProviderStateMixin {
  final pinService = PinService();
  late int _step; // 0=verify, 1=new, 2=confirm
  String _input = '';
  String _newPin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  final List<IconData> _stepIcons = [
    Icons.lock_outline,
    Icons.edit_outlined,
    Icons.check_circle_outline,
  ];

  @override
  void initState() {
    super.initState();
    // Если PIN нет, начинаем сразу с шага создания (1) [cite: 2026-03-08]
    _step = widget.hasExistingPin ? 0 : 1;

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_input.length >= 4) return;
    setState(() => _input += digit);
    if (_input.length >= 4) {
      Future.delayed(const Duration(milliseconds: 150), _onComplete);
    }
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _onComplete() async {
    if (_step == 0) {
      final valid = await pinService.verifyPin(_input);
      if (valid) {
        setState(() {
          _step = 1;
          _input = '';
        });
      } else {
        _shakeAndClear();
      }
    } else if (_step == 1) {
      setState(() {
        _newPin = _input;
        _step = 2;
        _input = '';
      });
    } else {
      if (_input == _newPin) {
        await pinService.setPin(_input);
        HapticFeedback.mediumImpact();
        if (mounted) Navigator.pop(context, true);
      } else {
        _shakeAndClear();
      }
    }
  }

  void _shakeAndClear() {
    HapticFeedback.vibrate();
    _shakeController.forward(from: 0).then((_) {
      setState(() => _input = '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final fg = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              _stepIcons[_step],
              key: ValueKey(_step),
              size: 48,
              color: DokkiColors.primaryTeal,
            ),
          ),
          const SizedBox(height: 32),
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              final offset = _shakeController.isAnimating
                  ? 8 *
                          (0.5 - (_shakeAnimation.value % 0.25) / 0.25).abs() *
                          2 -
                      1
                  : 0.0;
              return Transform.translate(
                offset: Offset(offset * 10, 0),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _input.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? DokkiColors.primaryTeal
                        : fg.withValues(alpha: 0.1),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              children: [
                for (final row in [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                  ['', '0', '⌫']
                ])
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: row
                        .map((d) => _DigitButton(
                              label: d,
                              color: fg,
                              onTap: d == '⌫'
                                  ? _onDelete
                                  : d.isEmpty
                                      ? null
                                      : () => _onDigit(d),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DigitButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _DigitButton({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: label == '⌫' ? 24 : 28,
            fontWeight: FontWeight.w300,
            color: onTap == null ? Colors.transparent : color,
          ),
        ),
      ),
    );
  }
}
