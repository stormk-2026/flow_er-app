import 'package:flutter/material.dart';

import '../../../core/theme/splash_colors.dart';

/// 水波扩散：中心实心圆 + 多圈向外晕染的环形波纹。
class ZenRipple extends StatefulWidget {
  const ZenRipple({super.key, this.size = 220});

  final double size;

  @override
  State<ZenRipple> createState() => _ZenRippleState();
}

class _ZenRippleState extends State<ZenRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _coreRadius = 28.0;
  static const _waveCount = 4;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _ZenRipplePainter(
              progress: _controller.value,
              coreRadius: _coreRadius,
            ),
          );
        },
      ),
    );
  }
}

class _ZenRipplePainter extends CustomPainter {
  _ZenRipplePainter({required this.progress, required this.coreRadius});

  final double progress;
  final double coreRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.48;

    // 静态内圈晕染（设计稿里紧贴圆心的柔和色带）
    final haloPaint = Paint()
      ..color = SplashColors.ripple.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, coreRadius + 14, haloPaint);

    final haloStroke = Paint()
      ..color = SplashColors.ripple.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, coreRadius + 36, haloStroke);

    // 动态波纹：#516356，10% 透明度，向外扩散并逐渐变淡
    for (var i = 0; i < _ZenRippleState._waveCount; i++) {
      final phase = (progress + i / _ZenRippleState._waveCount) % 1.0;
      final radius = coreRadius + phase * (maxRadius - coreRadius);
      final fade = 1 - Curves.easeOut.transform(phase);
      final alpha = 0.1 * fade;

      if (alpha <= 0.005) continue;

      final ringPaint = Paint()
        ..color = SplashColors.ripple.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 - 1.6 * phase;

      canvas.drawCircle(center, radius, ringPaint);

      // 轻微填充晕染，更像水波扩散而非纯描边
      final bleedPaint = Paint()
        ..color = SplashColors.ripple.withValues(alpha: alpha * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringPaint.strokeWidth * 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center, radius, bleedPaint);
    }

    // 最外层静态细线（设计稿最外圈淡灰环）
    final outerRing = Paint()
      ..color = SplashColors.divider.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, maxRadius * 0.92, outerRing);

    // 中心实心圆 #737873
    final corePaint = Paint()
      ..color = SplashColors.coreCircle
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, coreRadius, corePaint);
  }

  @override
  bool shouldRepaint(covariant _ZenRipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
