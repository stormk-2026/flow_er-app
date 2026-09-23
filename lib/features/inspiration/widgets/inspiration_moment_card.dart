import 'dart:math' as math;
import 'dart:io';
import '../../../core/widgets/private_journal_image.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/day_night_theme.dart';
import '../models/inspiration_moment.dart';

class InspirationMomentCard extends StatelessWidget {
  const InspirationMomentCard({super.key, required this.moment, this.onDelete});

  final InspirationMoment moment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return _FlipMomentCard(moment: moment, onDelete: onDelete);
  }
}

class _FlipMomentCard extends StatefulWidget {
  const _FlipMomentCard({required this.moment, this.onDelete});

  final InspirationMoment moment;
  final VoidCallback? onDelete;

  @override
  State<_FlipMomentCard> createState() => _FlipMomentCardState();
}

class _FlipMomentCardState extends State<_FlipMomentCard>
    with SingleTickerProviderStateMixin {
  bool _showBack = false;
  bool _showDelete = false;
  Timer? _pendingTimer;
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  bool get _ready => widget.moment.hasAiComment;
  bool get _waitingTooLong =>
      DateTime.now().difference(widget.moment.createdAt) >=
      const Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    _watchPending();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animateReady();
  }

  void _animateReady() {
    _nudge.stop();
    _nudge.value = 0;
    if (_ready && !MediaQuery.disableAnimationsOf(context)) {
      // A short invitation, rather than a permanently moving feed.
      _nudge.repeat(count: 3);
    }
  }

  void _watchPending() {
    _pendingTimer?.cancel();
    if (!_ready && !_waitingTooLong) {
      final remaining =
          const Duration(minutes: 2) -
          DateTime.now().difference(widget.moment.createdAt);
      _pendingTimer = Timer(remaining, () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    _nudge.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FlipMomentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moment.stableKey != widget.moment.stableKey) {
      _showBack = false;
      _showDelete = false;
    }
    if (!_ready) _showBack = false;
    if (oldWidget.moment.stableKey != widget.moment.stableKey ||
        oldWidget.moment.hasAiComment != _ready) {
      _watchPending();
      _animateReady();
    }
  }

  void _toggleSide() {
    if (!_ready || _showDelete) return;
    setState(() => _showBack = !_showBack);
  }

  Widget _buildCorner(bool showingBack) => Positioned(
    top: 0,
    right: 0,
    child: Semantics(
      label: _ready
          ? (showingBack ? '翻回心笺正面' : '回响已就绪，点击翻转')
          : (_waitingTooLong ? '回响尚未就绪，可下拉刷新' : '回响生成中，暂不可翻转'),
      button: _ready,
      child: Tooltip(
        message: _ready
            ? '点击角标或双击卡片翻转'
            : (_waitingTooLong ? '回响尚未就绪，可下拉刷新' : '回响生成中…'),
        child: GestureDetector(
          onTap: _ready ? _toggleSide : null,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(24),
            ),
            child: ClipPath(
              clipper: const _CornerClipper(),
              child: ColoredBox(
                key: ValueKey(_ready ? 'echo-ready' : 'echo-pending'),
                color: _ready
                    ? const Color(0xFF668D75)
                    : const Color(0xFF939A98),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Align(
                    alignment: const Alignment(0.45, -0.45),
                    child: AnimatedBuilder(
                      animation: _nudge,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                          0,
                          -2 * math.sin(_nudge.value * math.pi * 2),
                        ),
                        child: child,
                      ),
                      child: Icon(
                        _ready
                            ? Icons.swap_horiz_rounded
                            : Icons.more_horiz_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) {
        if (_showDelete) setState(() => _showDelete = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: widget.onDelete == null
            ? null
            : () => setState(() => _showDelete = true),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Visibility(
              visible: false,
              maintainSize: true,
              maintainState: true,
              maintainAnimation: true,
              child: _UnifiedGlassMomentCard(
                moment: widget.moment,
                onDelete: widget.onDelete,
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: _showBack ? math.pi : 0),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 460),
                  curve: Curves.easeInOutCubic,
                  builder: (context, angle, child) {
                    final showingBack = angle > math.pi / 2;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(angle),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(showingBack ? math.pi : 0),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onDoubleTap: _ready && !_showDelete
                                  ? _toggleSide
                                  : null,
                              child: showingBack
                                  ? _MomentBackCard(
                                      moment: widget.moment,
                                      onDelete: widget.onDelete,
                                    )
                                  : _UnifiedGlassMomentCard(
                                      moment: widget.moment,
                                      onDelete: widget.onDelete,
                                    ),
                            ),
                            _buildCorner(showingBack),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_showDelete)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: GestureDetector(
                    key: const ValueKey('delete-overlay'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _showDelete = false),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.34),
                      child: Center(
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            setState(() => _showDelete = false);
                            widget.onDelete?.call();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.surface.withValues(
                              alpha: 0.95,
                            ),
                            foregroundColor: const Color(0xFF9B4D45),
                            minimumSize: const Size(100, 48),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('删除心笺'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CornerClipper extends CustomClipper<Path> {
  const _CornerClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..close();

  @override
  bool shouldReclip(_CornerClipper oldClipper) => false;
}

class _UnifiedGlassMomentCard extends StatelessWidget {
  const _UnifiedGlassMomentCard({required this.moment, this.onDelete});

  final InspirationMoment moment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;
    final hasTitle = moment.title.trim().isNotEmpty;
    final hasImages = moment.localImagePaths.isNotEmpty;
    final isPlainText = !hasTitle && !hasImages;
    final night = isNightTheme;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.065),
              blurRadius: 22,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 172),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: night
                    ? AppColors.surface.withValues(alpha: 0.62)
                    : Colors.white.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: night ? 0.1 : 0.62),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardHeader(moment: moment, onDelete: onDelete),
                        const SizedBox(height: 8),
                        if (hasTitle) ...[
                          Text(
                            moment.title,
                            style: GoogleFonts.notoSansSc(
                              fontSize: 17,
                              height: 1.38,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _CardBodyText(
                          text: moment.body,
                          hasTitle: hasTitle,
                          centered: isPlainText,
                        ),
                        if (hasImages) ...[
                          const SizedBox(height: 14),
                          moment.localImagePaths.length == 1
                              ? _PhotoHero(paths: moment.localImagePaths)
                              : _PhotoGrid(paths: moment.localImagePaths),
                        ],
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: night ? 0.08 : 0.28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MomentBackCard extends StatelessWidget {
  const _MomentBackCard({required this.moment, this.onDelete});

  final InspirationMoment moment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;
    final night = isNightTheme;
    final comment = moment.aiComment?.trim();
    final text = comment?.isNotEmpty == true
        ? comment!
        : '流境正在等一阵风，把这张心笺背后的回声带回来。';

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: night ? 0.16 : 0.075),
              blurRadius: 24,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: night
                  ? AppColors.surface.withValues(alpha: 0.66)
                  : Colors.white.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: night ? 0.1 : 0.56),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '回响',
                        style: GoogleFonts.notoSansSc(
                          fontSize: 12,
                          height: 1,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 30),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSerifSc(
                            fontSize: 18,
                            height: 1.72,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.84,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Align(
                  //   alignment: Alignment.centerRight,
                  //   child: Text(
                  //     '回响',
                  //     style: GoogleFonts.notoSansSc(
                  //       fontSize: 11,
                  //       height: 1,
                  //       color: AppColors.textMuted,
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBodyText extends StatelessWidget {
  const _CardBodyText({
    required this.text,
    required this.hasTitle,
    required this.centered,
  });

  final String text;
  final bool hasTitle;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    if (!centered) {
      return Text(
        text,
        style: GoogleFonts.notoSansSc(
          fontSize: hasTitle ? 14 : 16,
          height: 1.72,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary.withValues(alpha: 0.78),
        ),
      );
    }

    return SizedBox(
      height: 104,
      child: Center(
        child: SingleChildScrollView(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              fontSize: _plainTextSize(text),
              height: 1.68,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary.withValues(alpha: 0.82),
            ),
          ),
        ),
      ),
    );
  }

  double _plainTextSize(String value) {
    final length = value.characters.length;
    if (length <= 14) return 22;
    if (length <= 28) return 19;
    if (length <= 48) return 17;
    return 15;
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.moment, this.onDelete});

  final InspirationMoment moment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final date = moment.createdAt.toLocal();
    final dateText =
        '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          dateText,
          style: GoogleFonts.playfairDisplay(
            fontSize: 16,
            height: 1,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary.withValues(alpha: 0.72),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _HeaderTags(moment: moment),
          ),
        ),
        const SizedBox(width: 30, height: 32),
      ],
    );
  }
}

class _HeaderTags extends StatelessWidget {
  const _HeaderTags({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: moment.tags.take(1).map((tag) {
        return Container(
          padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
          decoration: BoxDecoration(
            color: AppColors.accentSoft.withValues(
              alpha: isNightTheme ? 0.9 : 0.82,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primaryAction.withValues(
                alpha: isNightTheme ? 0.22 : 0.18,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 2,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.primaryAction.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                tag,
                style: GoogleFonts.notoSerifSc(
                  fontSize: 12,
                  height: 1,
                  color: AppColors.textPrimary.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PhotoHero extends StatelessWidget {
  const _PhotoHero({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: _PhotoTile(path: paths.first, allPaths: paths),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    if (paths.length == 1) return _PhotoHero(paths: paths);
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.12,
      children: paths
          .take(4)
          .map((path) => _PhotoTile(path: path, allPaths: paths))
          .toList(),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path, this.allPaths});

  final String path;
  final List<String>? allPaths;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openImagePreview(context, path, allPaths ?? [path]),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final cacheExtent = (constraints.maxWidth * dpr)
              .clamp(360.0, 1080.0)
              .round();
          return ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: _imageFor(path, cacheWidth: cacheExtent),
          );
        },
      ),
    );
  }

  Widget _imageFor(String path, {required int cacheWidth}) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return PrivateJournalImage(
        url: path,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      cacheWidth: cacheWidth,
    );
  }
}

void _openImagePreview(
  BuildContext context,
  String initialPath,
  List<String> paths,
) {
  final initialPage = paths.indexOf(initialPath).clamp(0, paths.length - 1);
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (context) {
      final controller = PageController(initialPage: initialPage);
      return Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: paths.length,
            itemBuilder: (context, index) {
              final path = paths[index];
              final image =
                  path.startsWith('http://') || path.startsWith('https://')
                  ? PrivateJournalImage(url: path, fit: BoxFit.contain)
                  : Image.file(File(path));
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(child: image),
              );
            },
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      );
    },
  );
}
