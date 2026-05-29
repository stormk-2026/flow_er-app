import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/thought_capture_mode.dart';
import '../../../providers/app_providers.dart';
import '../../../services/journal/journal_image_store.dart';

/// 心流中下滑触发：快记 / 展笺，收入心笺。
/// 提交时调 [onSubmitting] 传出 AI future，父组件显示保存结果。
class ThoughtCaptureOverlay extends ConsumerStatefulWidget {
  const ThoughtCaptureOverlay({
    super.key,
    required this.onDismiss,
    required this.onSubmitting,
  });

  final VoidCallback onDismiss;
  final ValueChanged<Future<void>> onSubmitting;

  @override
  ConsumerState<ThoughtCaptureOverlay> createState() =>
      _ThoughtCaptureOverlayState();
}

class _ThoughtCaptureOverlayState extends ConsumerState<ThoughtCaptureOverlay>
    with SingleTickerProviderStateMixin {
  ThoughtCaptureMode _mode = ThoughtCaptureMode.quick;
  final _quickController = TextEditingController();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _imagePaths = <String>[];
  final _picker = ImagePicker();

  late final AnimationController _ctrl;
  late final Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _quickController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  Future<void> _pickImages() async {
    final remaining = JournalImageStore.maxImages - _imagePaths.length;
    if (remaining <= 0) return;
    final picks = await _picker.pickMultiImage(imageQuality: 85, limit: remaining);
    if (picks.isEmpty || !mounted) return;
    final stored = await JournalImageStore.persistPicks(picks);
    if (!mounted) return;
    setState(() => _imagePaths.addAll(stored));
  }

  Future<void> _submit() async {
    final future = ref.read(intentControllerProvider.notifier).saveJournal(
          mode: _mode,
          quickText: _quickController.text,
          title: _titleController.text,
          body: _bodyController.text,
          imagePaths: _imagePaths,
        );
    widget.onSubmitting(future);
    widget.onDismiss();
  }

  bool get _canSubmit {
    if (_mode == ThoughtCaptureMode.quick) {
      return _quickController.text.trim().isNotEmpty;
    }
    return _titleController.text.trim().isNotEmpty ||
        _bodyController.text.trim().isNotEmpty ||
        _imagePaths.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 点击卡片外区域关闭
        Positioned.fill(
          child: GestureDetector(onTap: _dismiss),
        ),
        // 卡片：从底部滑入
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: _cardSlide,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomInset),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            '记下此刻',
                            style: GoogleFonts.notoSansSc(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              letterSpacing: 1,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: _dismiss,
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _ModeToggle(
                        mode: _mode,
                        onChanged: (m) => setState(() => _mode = m),
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: SingleChildScrollView(
                          child: _mode == ThoughtCaptureMode.quick
                              ? _buildQuickField()
                              : _buildExpandedFields(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _canSubmit ? _submit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF516356),
                          disabledBackgroundColor:
                              const Color(0xFF516356).withValues(alpha: 0.35),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          '收入心笺',
                          style: GoogleFonts.notoSansSc(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickField() {
    return TextField(
      controller: _quickController,
      autofocus: true,
      maxLines: 3,
      minLines: 1,
      onChanged: (_) => setState(() {}),
      decoration: _fieldDecoration('一句话，记下想法或感受…'),
      style: GoogleFonts.notoSansSc(fontSize: 14),
      onSubmitted: _canSubmit ? (_) => _submit() : null,
    );
  }

  Widget _buildExpandedFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titleController,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: _fieldDecoration('标题'),
          style: GoogleFonts.notoSansSc(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bodyController,
          maxLines: 6,
          minLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: _fieldDecoration('正文 · 感受 · 日记'),
          style: GoogleFonts.notoSansSc(fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 12),
        Text(
          '图片（${_imagePaths.length}/${JournalImageStore.maxImages}）',
          style: GoogleFonts.notoSansSc(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._imagePaths.asMap().entries.map(
                  (e) => _ImageThumb(
                    path: e.value,
                    onRemove: () => setState(() => _imagePaths.removeAt(e.key)),
                  ),
                ),
            if (_imagePaths.length < JournalImageStore.maxImages)
              _AddImageButton(onTap: _pickImages),
          ],
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.notoSansSc(fontSize: 13, color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final ThoughtCaptureMode mode;
  final ValueChanged<ThoughtCaptureMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ThoughtCaptureMode.values.map((m) {
          final selected = mode == m;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  m.label,
                  style: GoogleFonts.notoSansSc(
                    fontSize: 13,
                    color: selected ? const Color(0xFF516356) : AppColors.textMuted,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.path, this.onRemove});

  final String path;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(path),
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddImageButton extends StatelessWidget {
  const _AddImageButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: AppColors.navIcon,
          size: 26,
        ),
      ),
    );
  }
}
