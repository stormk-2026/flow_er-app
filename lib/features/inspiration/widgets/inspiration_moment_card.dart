import 'dart:math' as math;
import 'dart:io';

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

class _FlipMomentCardState extends State<_FlipMomentCard> {
  bool _showBack = false;

  @override
  void didUpdateWidget(covariant _FlipMomentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moment.stableKey != widget.moment.stableKey) {
      _showBack = false;
    }
  }

  void _toggleSide() {
    setState(() => _showBack = !_showBack);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _toggleSide,
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
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _showBack ? math.pi : 0),
              duration: const Duration(milliseconds: 460),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
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
                      if (onDelete != null)
                        _CardMenu(
                          tint: AppColors.textMuted,
                          onDelete: onDelete,
                        ),
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
        Expanded(child: _HeaderTags(moment: moment)),
        if (onDelete != null)
          _CardMenu(tint: AppColors.textMuted, onDelete: onDelete),
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

class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.tint, this.onDelete});

  final Color tint;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CardAction>(
      tooltip: '更多',
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 20,
        color: tint.withValues(alpha: 0.72),
      ),
      color: AppColors.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (_) => onDelete?.call(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _CardAction.delete,
          child: Text(
            '删除',
            style: GoogleFonts.notoSansSc(
              fontSize: 13,
              color: const Color(0xFF9B4D45),
            ),
          ),
        ),
      ],
    );
  }
}

enum _CardAction { delete }

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
      return Image.network(
        path,
        fit: BoxFit.cover,
        alignment: Alignment.center,
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
                  ? Image.network(path)
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
