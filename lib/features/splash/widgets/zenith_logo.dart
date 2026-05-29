import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/splash_colors.dart';

class ZenithLogo extends StatelessWidget {
  const ZenithLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: const Size(14, 14), painter: _ZenithMarkPainter()),
        const SizedBox(width: 8),
        Text(
          'FLOW ER',
          style: GoogleFonts.inter(
            fontSize: 11,
            letterSpacing: 3.2,
            fontWeight: FontWeight.w500,
            color: SplashColors.brand,
          ),
        ),
      ],
    );
  }
}

class _ZenithMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..color = SplashColors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, 5.5, stroke);
    canvas.drawCircle(center, 1.8, Paint()..color = SplashColors.brand);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
