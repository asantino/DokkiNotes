import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../theme/dokki_theme.dart';

class PinInputDialog extends StatefulWidget {
  final bool isConfirmation;
  final Future<bool> Function(String)? verifyPin;

  const PinInputDialog({
    super.key,
    this.isConfirmation = true,
    this.verifyPin,
  });

  @override
  State<PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<PinInputDialog>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _error = '';

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

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
    _shakeController.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    HapticFeedback.lightImpact();
    setState(() {
      _error = '';

      if (!_isConfirming) {
        if (_pin.length < 4) {
          _pin += number;
        }

        if (_pin.length == 4) {
          if (widget.isConfirmation) {
            _isConfirming = true;
          } else {
            if (widget.verifyPin != null) {
              widget.verifyPin!(_pin).then((isValid) {
                if (!mounted) return;
                if (isValid) {
                  Navigator.pop(context, _pin);
                } else {
                  setState(() {
                    _error = 'error';
                    _pin = '';
                  });
                  _shakeController.forward(from: 0);
                  HapticFeedback.heavyImpact();
                }
              });
            } else {
              Navigator.pop(context, _pin);
            }
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += number;
        }

        if (_confirmPin.length == 4) {
          if (_pin == _confirmPin) {
            Navigator.pop(context, _pin);
          } else {
            _error = 'error';
            _confirmPin = '';
            _shakeController.forward(from: 0);
            HapticFeedback.heavyImpact();
          }
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (!_isConfirming && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      } else if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else if (_isConfirming && _confirmPin.isEmpty) {
        _isConfirming = false;
      }
      _error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _pin;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child!,
        );
      },
      child: Dialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isConfirming
                    ? CupertinoIcons.lock_shield_fill
                    : CupertinoIcons.lock_shield,
                size: 48,
                color: DokkiColors.primaryTeal,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  bool isFilled = index < currentPin.length;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? DokkiColors.primaryTeal
                          : Colors.grey.withAlpha(50),
                      border: !isFilled
                          ? Border.all(
                              color: Colors.grey.withAlpha(100), width: 1.5)
                          : null,
                    ),
                  );
                }),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: Colors.red,
                  size: 32,
                ),
              ],
              const SizedBox(height: 40),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  ...List.generate(9, (index) {
                    final number = (index + 1).toString();
                    return _NumberButton(
                      number: number,
                      onPressed: () => _onNumberPressed(number),
                    );
                  }),
                  _CancelButton(onPressed: () => Navigator.pop(context)),
                  _NumberButton(
                      number: '0', onPressed: () => _onNumberPressed('0')),
                  _BackspaceButton(onPressed: _onBackspace),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberButton extends StatelessWidget {
  final String number;
  final VoidCallback onPressed;
  const _NumberButton({required this.number, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withAlpha(77)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            number,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _BackspaceButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _BackspaceButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withAlpha(77)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(CupertinoIcons.delete_left, size: 28),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CancelButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withAlpha(77)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            CupertinoIcons.xmark,
            size: 28,
            color: Colors.grey.withAlpha(180),
          ),
        ),
      ),
    );
  }
}
