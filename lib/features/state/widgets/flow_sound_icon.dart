import 'package:flutter/material.dart';

/// Both states keep the same waveform; only the mute slash changes.
class FlowSoundIcon extends StatelessWidget {
  const FlowSoundIcon({super.key, required this.muted, required this.color});

  final bool muted;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 24,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Icon(Icons.graphic_eq_rounded, size: 24, color: color),
        if (muted)
          CustomPaint(
            key: const ValueKey('flow-sound-mute-slash'),
            painter: _MuteSlash(color),
          ),
      ],
    ),
  );
}

class _MuteSlash extends CustomPainter {
  const _MuteSlash(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * 0.14, size.height * 0.14),
      Offset(size.width * 0.86, size.height * 0.86),
      Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_MuteSlash oldDelegate) => oldDelegate.color != color;
}
