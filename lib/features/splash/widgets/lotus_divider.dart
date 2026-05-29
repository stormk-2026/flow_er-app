import 'package:flutter/material.dart';

import '../../../core/theme/splash_colors.dart';

class LotusDivider extends StatelessWidget {
  const LotusDivider({super.key, this.width = 200});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 24,
      child: Row(
        children: [
          Expanded(child: _line()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: CustomPaint(
              size: const Size(18, 18),
              painter: _LotusPainter(),
            ),
          ),
          Expanded(child: _line()),
        ],
      ),
    );
  }

  Widget _line() {
    return Container(height: 0.5, color: SplashColors.divider);
  }
}

class _LotusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SplashColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // 简化的莲花线稿
    final path = Path();
    path.moveTo(cx, cy + 6);
    path.quadraticBezierTo(cx - 5, cy - 2, cx - 7, cy - 5);
    path.quadraticBezierTo(cx - 2, cy - 1, cx, cy - 7);
    path.quadraticBezierTo(cx + 2, cy - 1, cx + 7, cy - 5);
    path.quadraticBezierTo(cx + 5, cy - 2, cx, cy + 6);
    canvas.drawPath(path, paint);

    canvas.drawCircle(
      Offset(cx, cy - 1),
      1.2,
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
