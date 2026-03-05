import 'package:flutter/material.dart';

class AiMicIcon extends StatelessWidget {
  final double size;
  final Color color;

  const AiMicIcon({
    super.key,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.mic_none_rounded,
            color: color,
            size: size,
          ),
          Positioned(
            top: -2,
            right: -4,
            child: Icon(
              Icons.auto_awesome,
              color: color,
              size: size * 0.45,
            ),
          ),
        ],
      ),
    );
  }
}
