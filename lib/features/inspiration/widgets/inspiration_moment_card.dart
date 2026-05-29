import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../models/inspiration_moment.dart';

class InspirationMomentCard extends StatelessWidget {
  const InspirationMomentCard({
    super.key,
    required this.moment,
    this.onEdit,
    this.onDelete,
  });

  final InspirationMoment moment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final child = switch (moment.variant.mode) {
      InspirationMode.quick => _buildQuick(context),
      InspirationMode.expanded => _buildExpanded(context),
    };

    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              moment.tone.wash.withValues(alpha: moment.tone.opacity),
              AppColors.surface,
            ),
            borderRadius: BorderRadius.circular(moment.tone.radius),
            border: Border.all(color: moment.tone.tint.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: moment.tone.elevation),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(moment.tone.radius),
            child: child,
          ),
        ),
        if (onEdit != null || onDelete != null)
          Positioned(
            top: 8,
            right: 8,
            child: _CardMenu(
              tint: moment.tone.tint,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
      ],
    );
  }

  Widget _buildQuick(BuildContext context) {
    return switch ((moment.category, moment.variant.index)) {
      (InspirationCategory.ingenuity, 0) => _QuickSeed(moment: moment),
      (InspirationCategory.ingenuity, 1) => _QuickMarginNote(moment: moment),
      (InspirationCategory.ingenuity, _) => _QuickSplitInk(moment: moment),
      (InspirationCategory.reflection, 0) => _QuickCenteredVerse(
        moment: moment,
      ),
      (InspirationCategory.reflection, 1) => _QuickLayeredPaper(moment: moment),
      (InspirationCategory.reflection, _) => _QuickQuietColumn(moment: moment),
      (InspirationCategory.mood, 0) => _QuickMistPanel(moment: moment),
      (InspirationCategory.mood, 1) => _QuickBreathBand(moment: moment),
      (InspirationCategory.mood, _) => _QuickMoonNote(moment: moment),
      (InspirationCategory.chronicle, 0) => _QuickTimelineDot(moment: moment),
      (InspirationCategory.chronicle, 1) => _QuickDateSlip(moment: moment),
      (InspirationCategory.chronicle, _) => _QuickPlainLog(moment: moment),
      (InspirationCategory.excerpt, 0) => _QuickQuoteSeal(moment: moment),
      (InspirationCategory.excerpt, 1) => _QuickBookMark(moment: moment),
      (InspirationCategory.excerpt, _) => _QuickExcerptFrame(moment: moment),
    };
  }

  Widget _buildExpanded(BuildContext context) {
    return switch ((moment.category, moment.variant.index)) {
      (InspirationCategory.ingenuity, 0) => _ExpandedNotebook(moment: moment),
      (InspirationCategory.ingenuity, 1) => _ExpandedImageLead(moment: moment),
      (InspirationCategory.ingenuity, _) => _ExpandedSideImage(moment: moment),
      (InspirationCategory.reflection, 0) => _ExpandedEssay(moment: moment),
      (InspirationCategory.reflection, 1) => _ExpandedGalleryTop(
        moment: moment,
      ),
      (InspirationCategory.reflection, _) => _ExpandedInsetPhoto(
        moment: moment,
      ),
      (InspirationCategory.mood, 0) => _ExpandedSoftJournal(moment: moment),
      (InspirationCategory.mood, 1) => _ExpandedMoodWash(moment: moment),
      (InspirationCategory.mood, _) => _ExpandedImageTrail(moment: moment),
      (InspirationCategory.chronicle, 0) => _ExpandedDayRecord(moment: moment),
      (InspirationCategory.chronicle, 1) => _ExpandedLogWithImage(
        moment: moment,
      ),
      (InspirationCategory.chronicle, _) => _ExpandedTimestampBlock(
        moment: moment,
      ),
      (InspirationCategory.excerpt, 0) => _ExpandedQuotePage(moment: moment),
      (InspirationCategory.excerpt, 1) => _ExpandedExcerptImage(moment: moment),
      (InspirationCategory.excerpt, _) => _ExpandedCitationPanel(
        moment: moment,
      ),
    };
  }
}

class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.tint, this.onEdit, this.onDelete});

  final Color tint;
  final VoidCallback? onEdit;
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
      onSelected: (action) {
        switch (action) {
          case _CardAction.edit:
            onEdit?.call();
          case _CardAction.delete:
            onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem(
            value: _CardAction.edit,
            child: Text('编辑', style: GoogleFonts.notoSansSc(fontSize: 13)),
          ),
        if (onDelete != null)
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

enum _CardAction { edit, delete }

class _QuickSeed extends StatelessWidget {
  const _QuickSeed({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetaRow(moment: moment),
          const SizedBox(height: 18),
          Text(moment.body, style: _serif(moment, 24, 1.42)),
          const SizedBox(height: 18),
          _Hairline(moment),
        ],
      ),
    );
  }
}

class _QuickMarginNote extends StatelessWidget {
  const _QuickMarginNote({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VerticalBadge(moment: moment),
          const SizedBox(width: 16),
          Expanded(child: Text(moment.body, style: _sans(moment, 17, 1.78))),
        ],
      ),
    );
  }
}

class _QuickSplitInk extends StatelessWidget {
  const _QuickSplitInk({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: moment.tone.gradient,
        ),
      ),
      child: _CardPadding(
        moment: moment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Badge(moment: moment),
            const SizedBox(height: 34),
            Text(moment.body, style: _serif(moment, 20, 1.55)),
            const SizedBox(height: 18),
            _Tags(moment: moment),
          ],
        ),
      ),
    );
  }
}

class _QuickCenteredVerse extends StatelessWidget {
  const _QuickCenteredVerse({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        children: [
          _Hairline(moment),
          const SizedBox(height: 22),
          Text(
            moment.body,
            textAlign: TextAlign.center,
            style: _serif(moment, 22, 1.58),
          ),
          const SizedBox(height: 22),
          _Badge(moment: moment),
        ],
      ),
    );
  }
}

class _QuickLayeredPaper extends StatelessWidget {
  const _QuickLayeredPaper({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 16,
          right: 18,
          child: _SoftCircle(moment: moment, size: 84),
        ),
        _CardPadding(
          moment: moment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaRow(moment: moment),
              const SizedBox(height: 20),
              Text(moment.body, style: _sans(moment, 16, 1.85)),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickQuietColumn extends StatelessWidget {
  const _QuickQuietColumn({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            moment.body,
            textAlign: TextAlign.start,
            style: _serif(moment, 19, 1.75),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: _Tags(moment: moment),
          ),
        ],
      ),
    );
  }
}

class _QuickMistPanel extends StatelessWidget {
  const _QuickMistPanel({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.15,
          colors: [
            moment.tone.accent.withValues(alpha: 0.18),
            AppColors.surface.withValues(alpha: 0),
          ],
        ),
      ),
      child: _CardPadding(
        moment: moment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Badge(moment: moment),
            const SizedBox(height: 18),
            Text(moment.body, style: _sans(moment, 18, 1.72)),
          ],
        ),
      ),
    );
  }
}

class _QuickBreathBand extends StatelessWidget {
  const _QuickBreathBand({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: moment.tone.tint.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            moment.body,
            textAlign: TextAlign.center,
            style: _sans(moment, 18, 1.8),
          ),
          const SizedBox(height: 20),
          _Tags(moment: moment, centered: true),
        ],
      ),
    );
  }
}

class _QuickMoonNote extends StatelessWidget {
  const _QuickMoonNote({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: -20,
          bottom: -20,
          child: _SoftCircle(moment: moment, size: 118),
        ),
        _CardPadding(
          moment: moment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Badge(moment: moment),
              const SizedBox(height: 26),
              Text(
                moment.body,
                textAlign: TextAlign.right,
                style: _serif(moment, 20, 1.62),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickTimelineDot extends StatelessWidget {
  const _QuickTimelineDot({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _TinyDot(moment),
              Container(
                width: 1,
                height: 72,
                color: moment.tone.tint.withValues(alpha: 0.14),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateText(moment: moment),
                const SizedBox(height: 10),
                Text(moment.body, style: _sans(moment, 16, 1.72)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickDateSlip extends StatelessWidget {
  const _QuickDateSlip({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            moment.tone.tint.withValues(alpha: 0.08),
            AppColors.surface.withValues(alpha: 0),
          ],
        ),
      ),
      child: _CardPadding(
        moment: moment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateText(moment: moment),
            const SizedBox(height: 16),
            Text(moment.body, style: _serif(moment, 19, 1.58)),
            const SizedBox(height: 14),
            _Tags(moment: moment),
          ],
        ),
      ),
    );
  }
}

class _QuickPlainLog extends StatelessWidget {
  const _QuickPlainLog({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _TinyDot(moment),
              const SizedBox(width: 10),
              Expanded(child: _Hairline(moment)),
            ],
          ),
          const SizedBox(height: 16),
          Text(moment.body, style: _sans(moment, 17, 1.76)),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: _DateText(moment: moment),
          ),
        ],
      ),
    );
  }
}

class _QuickQuoteSeal extends StatelessWidget {
  const _QuickQuoteSeal({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '“',
            style: _serif(moment, 48, 0.78).copyWith(color: moment.tone.tint),
          ),
          const SizedBox(height: 6),
          Text(
            moment.body,
            textAlign: TextAlign.center,
            style: _serif(moment, 21, 1.62),
          ),
          const SizedBox(height: 16),
          _Hairline(moment),
        ],
      ),
    );
  }
}

class _QuickBookMark extends StatelessWidget {
  const _QuickBookMark({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          right: 24,
          child: Container(
            width: 22,
            height: 62,
            color: moment.tone.accent.withValues(alpha: 0.2),
          ),
        ),
        _CardPadding(
          moment: moment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Tags(moment: moment),
              const SizedBox(height: 22),
              Text(moment.body, style: _serif(moment, 20, 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickExcerptFrame extends StatelessWidget {
  const _QuickExcerptFrame({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: moment.tone.tint.withValues(alpha: 0.13)),
          borderRadius: BorderRadius.circular(moment.tone.radius - 6),
        ),
        child: _CardPadding(
          moment: moment,
          child: Text(
            moment.body,
            textAlign: TextAlign.center,
            style: _serif(moment, 20, 1.68),
          ),
        ),
      ),
    );
  }
}

class _ExpandedNotebook extends StatelessWidget {
  const _ExpandedNotebook({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetaRow(moment: moment),
          const SizedBox(height: 14),
          _Title(moment: moment),
          const SizedBox(height: 12),
          _Body(moment: moment),
          if (moment.hasImage) ...[
            const SizedBox(height: 16),
            _PhotoGrid(paths: moment.localImagePaths),
          ],
        ],
      ),
    );
  }
}

class _ExpandedImageLead extends StatelessWidget {
  const _ExpandedImageLead({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (moment.hasImage) _PhotoHero(paths: moment.localImagePaths),
        _CardPadding(
          moment: moment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Badge(moment: moment),
              const SizedBox(height: 12),
              _Title(moment: moment),
              const SizedBox(height: 10),
              _Body(moment: moment),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpandedSideImage extends StatelessWidget {
  const _ExpandedSideImage({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    if (!moment.hasImage) return _ExpandedNotebook(moment: moment);
    return _CardPadding(
      moment: moment,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: AspectRatio(
              aspectRatio: 0.82,
              child: _PhotoTile(path: moment.localImagePaths.first),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Title(moment: moment, size: 18),
                const SizedBox(height: 8),
                _Body(moment: moment, maxLines: 7),
                const SizedBox(height: 12),
                _Tags(moment: moment),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedEssay extends StatelessWidget {
  const _ExpandedEssay({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Hairline(moment),
          const SizedBox(height: 18),
          _Title(moment: moment, centered: true, size: 22),
          const SizedBox(height: 14),
          _Body(moment: moment, centered: true),
          if (moment.hasImage) ...[
            const SizedBox(height: 18),
            _PhotoGrid(paths: moment.localImagePaths),
          ],
        ],
      ),
    );
  }
}

class _ExpandedGalleryTop extends StatelessWidget {
  const _ExpandedGalleryTop({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (moment.hasImage) ...[
            _PhotoGrid(paths: moment.localImagePaths),
            const SizedBox(height: 16),
          ],
          _MetaRow(moment: moment),
          const SizedBox(height: 12),
          _Title(moment: moment),
          const SizedBox(height: 10),
          _Body(moment: moment),
        ],
      ),
    );
  }
}

class _ExpandedInsetPhoto extends StatelessWidget {
  const _ExpandedInsetPhoto({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 18,
          right: 18,
          child: _SoftCircle(moment: moment, size: 92),
        ),
        _CardPadding(
          moment: moment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Title(moment: moment),
              const SizedBox(height: 12),
              if (moment.hasImage) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 132,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _PhotoTile(path: moment.localImagePaths.first),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _Body(moment: moment),
              const SizedBox(height: 12),
              _Tags(moment: moment),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpandedSoftJournal extends StatelessWidget {
  const _ExpandedSoftJournal({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            moment.tone.gradient.first.withValues(alpha: 0.9),
            AppColors.surface,
          ],
        ),
      ),
      child: _CardPadding(
        moment: moment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Badge(moment: moment),
            const SizedBox(height: 16),
            _Title(moment: moment),
            const SizedBox(height: 10),
            _Body(moment: moment),
            if (moment.hasImage) ...[
              const SizedBox(height: 16),
              _PhotoGrid(paths: moment.localImagePaths),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpandedMoodWash extends StatelessWidget {
  const _ExpandedMoodWash({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Title(moment: moment, centered: true, size: 21),
          const SizedBox(height: 12),
          _Body(moment: moment, centered: true),
          const SizedBox(height: 16),
          if (moment.hasImage) _PhotoHero(paths: moment.localImagePaths),
          if (!moment.hasImage) _Hairline(moment),
        ],
      ),
    );
  }
}

class _ExpandedImageTrail extends StatelessWidget {
  const _ExpandedImageTrail({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetaRow(moment: moment),
          const SizedBox(height: 12),
          _Title(moment: moment),
          const SizedBox(height: 10),
          _Body(moment: moment),
          if (moment.hasImage) ...[
            const SizedBox(height: 18),
            _PhotoStrip(paths: moment.localImagePaths),
          ],
        ],
      ),
    );
  }
}

class _ExpandedDayRecord extends StatelessWidget {
  const _ExpandedDayRecord({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateText(moment: moment),
          const SizedBox(height: 12),
          _Title(moment: moment),
          const SizedBox(height: 10),
          _Body(moment: moment),
          if (moment.hasImage) ...[
            const SizedBox(height: 16),
            _PhotoGrid(paths: moment.localImagePaths),
          ],
        ],
      ),
    );
  }
}

class _ExpandedLogWithImage extends StatelessWidget {
  const _ExpandedLogWithImage({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TinyDot(moment),
              const SizedBox(width: 10),
              Expanded(child: _Title(moment: moment, size: 19)),
            ],
          ),
          const SizedBox(height: 12),
          if (moment.hasImage) ...[
            _PhotoHero(paths: moment.localImagePaths),
            const SizedBox(height: 14),
          ],
          _Body(moment: moment),
          const SizedBox(height: 12),
          _Tags(moment: moment),
        ],
      ),
    );
  }
}

class _ExpandedTimestampBlock extends StatelessWidget {
  const _ExpandedTimestampBlock({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            moment.tone.gradient.first.withValues(alpha: 0.58),
          ],
        ),
      ),
      child: _CardPadding(
        moment: moment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MetaRow(moment: moment),
            const SizedBox(height: 18),
            _Title(moment: moment, size: 21),
            const SizedBox(height: 10),
            _Body(moment: moment),
            if (moment.hasImage) ...[
              const SizedBox(height: 16),
              _PhotoStrip(paths: moment.localImagePaths),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpandedQuotePage extends StatelessWidget {
  const _ExpandedQuotePage({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return _CardPadding(
      moment: moment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Tags(moment: moment, centered: true),
          const SizedBox(height: 16),
          _Title(moment: moment, centered: true, size: 20),
          const SizedBox(height: 14),
          Text(
            moment.body,
            textAlign: TextAlign.center,
            style: _serif(moment, 18, 1.75),
          ),
          if (moment.hasImage) ...[
            const SizedBox(height: 18),
            _PhotoGrid(paths: moment.localImagePaths),
          ],
        ],
      ),
    );
  }
}

class _ExpandedExcerptImage extends StatelessWidget {
  const _ExpandedExcerptImage({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (moment.hasImage) _PhotoHero(paths: moment.localImagePaths),
        _CardPadding(
          moment: moment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Title(moment: moment),
              const SizedBox(height: 12),
              Text(moment.body, style: _serif(moment, 18, 1.72)),
              const SizedBox(height: 14),
              _Hairline(moment),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpandedCitationPanel extends StatelessWidget {
  const _ExpandedCitationPanel({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 18,
          top: 14,
          child: Text(
            '“',
            style: _serif(
              moment,
              54,
              0.8,
            ).copyWith(color: moment.tone.tint.withValues(alpha: 0.18)),
          ),
        ),
        _CardPadding(
          moment: moment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _Title(moment: moment, size: 19),
              const SizedBox(height: 12),
              _Body(moment: moment),
              if (moment.hasImage) ...[
                const SizedBox(height: 16),
                _PhotoGrid(paths: moment.localImagePaths),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: _Tags(moment: moment),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardPadding extends StatelessWidget {
  const _CardPadding({required this.moment, required this.child});

  final InspirationMoment moment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final extra = (moment.id % 4).toDouble();
    return Padding(
      padding: EdgeInsets.fromLTRB(18 + extra, 18, 18 + extra, 18 + extra),
      child: child,
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.moment, this.centered = false, this.size = 20});

  final InspirationMoment moment;
  final bool centered;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      moment.title,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: _serif(moment, size, 1.28).copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.moment, this.centered = false, this.maxLines});

  final InspirationMoment moment;
  final bool centered;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      moment.body,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: _sans(moment, 14, 1.72),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Badge(moment: moment),
        const SizedBox(width: 10),
        Expanded(child: _Tags(moment: moment)),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: moment.tone.tint.withValues(alpha: 0.08),
        border: Border.all(color: moment.tone.tint.withValues(alpha: 0.08)),
      ),
      child: Text(
        moment.badge,
        style: GoogleFonts.notoSansSc(
          fontSize: 12,
          color: moment.tone.tint,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _VerticalBadge extends StatelessWidget {
  const _VerticalBadge({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Badge(moment: moment),
        const SizedBox(height: 10),
        Container(
          width: 1,
          height: 58,
          color: moment.tone.tint.withValues(alpha: 0.16),
        ),
      ],
    );
  }
}

class _Tags extends StatelessWidget {
  const _Tags({required this.moment, this.centered = false});

  final InspirationMoment moment;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      children: moment.tags.take(3).map((tag) {
        return Text(
          tag,
          style: GoogleFonts.notoSansSc(
            fontSize: 10,
            color: AppColors.textMuted,
            letterSpacing: 0.6,
          ),
        );
      }).toList(),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline(this.moment);

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      width: double.infinity,
      color: moment.tone.tint.withValues(alpha: 0.12),
    );
  }
}

class _TinyDot extends StatelessWidget {
  const _TinyDot(this.moment);

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: moment.tone.tint.withValues(alpha: 0.42),
      ),
    );
  }
}

class _DateText extends StatelessWidget {
  const _DateText({required this.moment});

  final InspirationMoment moment;

  @override
  Widget build(BuildContext context) {
    final date = moment.createdAt;
    final text =
        '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        color: AppColors.textMuted,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.moment, required this.size});

  final InspirationMoment moment;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: moment.tone.accent.withValues(alpha: 0.09),
      ),
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

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 126,
            child: _PhotoTile(path: paths[index], allPaths: paths),
          );
        },
      ),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: _imageFor(path),
      ),
    );
  }

  Widget _imageFor(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(path, fit: BoxFit.cover);
    }
    return Image.file(File(path), fit: BoxFit.cover);
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

TextStyle _serif(InspirationMoment moment, double size, double height) {
  return GoogleFonts.playfairDisplay(
    fontSize: size,
    height: height,
    color: AppColors.textPrimary,
    letterSpacing: 0,
  );
}

TextStyle _sans(InspirationMoment moment, double size, double height) {
  return GoogleFonts.notoSansSc(
    fontSize: size,
    height: height,
    color: AppColors.textPrimary.withValues(alpha: 0.78),
    letterSpacing: 0,
  );
}
