import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum MainTab { inspiration, state, analytics }

class ZenCapsuleNav extends StatefulWidget {
  const ZenCapsuleNav({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final MainTab current;
  final ValueChanged<MainTab> onChanged;

  @override
  State<ZenCapsuleNav> createState() => _ZenCapsuleNavState();
}

class _ZenCapsuleNavState extends State<ZenCapsuleNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _slideAnim;

  // 每个 tab 对应的滑块位置（0.0 左 → 1.0 右）
  static const _positions = {
    MainTab.inspiration: 0.0,
    MainTab.state: 0.5,
    MainTab.analytics: 1.0,
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = AlwaysStoppedAnimation(_positions[widget.current]!);
  }

  @override
  void didUpdateWidget(ZenCapsuleNav old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) {
      final from = _positions[old.current]!;
      final to = _positions[widget.current]!;
      _slideAnim = Tween<double>(begin: from, end: to).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.navCapsule,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _slideAnim,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // 滑动底色圆圈
                  _SlidingPill(position: _slideAnim.value),
                  // 三个图标
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: MainTab.values.map((tab) {
                      final isActive = widget.current == tab;
                      return _NavIcon(
                        tab: tab,
                        active: isActive,
                        onTap: () => widget.onChanged(tab),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// 滑动的底色圆圈，position: 0.0=左 0.5=中 1.0=右
class _SlidingPill extends StatelessWidget {
  const _SlidingPill({required this.position});

  final double position;

  static const _itemWidth = 68.0;
  static const _pillSize = 36.0;

  @override
  Widget build(BuildContext context) {
    // 三个 item 总宽 = 3 * 68，圆圈从第一个中心滑到最后一个中心
    final totalWidth = _itemWidth * 3;
    final left = position * (_itemWidth * 2) + (_itemWidth - _pillSize) / 2;
    final top = (48 - _pillSize) / 2; // 垂直居中于 48 高度的 icon 区域

    return SizedBox(
      width: totalWidth,
      height: 48,
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: Container(
              width: _pillSize,
              height: _pillSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                boxShadow: [
                  // 向下投影 — 圆圈本身的立体感
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                  // 顶部高光
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.18),
                    blurRadius: 2,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final MainTab tab;
  final bool active;
  final VoidCallback onTap;

  Key get _tabKey => switch (tab) {
    MainTab.inspiration => const Key('nav_inspiration'),
    MainTab.state => const Key('nav_state'),
    MainTab.analytics => const Key('nav_analytics'),
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _tabKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        height: 48,
        child: Center(
          child: AnimatedScale(
            scale: active ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                begin: active ? AppColors.navIcon : AppColors.navActive,
                end: active ? AppColors.navActive : AppColors.navIcon,
              ),
              duration: const Duration(milliseconds: 300),
              builder: (context, color, _) {
                return _buildIcon(color ?? AppColors.navIcon);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    return switch (tab) {
      MainTab.inspiration => CustomPaint(
        size: const Size(22, 22),
        painter: _RingDotPainter(color: color),
      ),
      MainTab.state => Icon(Icons.eco_outlined, size: 22, color: color),
      MainTab.analytics => Icon(
        Icons.person_outline_rounded,
        size: 22,
        color: color,
      ),
    };
  }
}

class _RingDotPainter extends CustomPainter {
  _RingDotPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(center, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingDotPainter old) => old.color != color;
}
