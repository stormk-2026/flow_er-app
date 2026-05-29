import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/app_database.dart';
import '../../providers/app_providers.dart';
import 'models/inspiration_moment.dart';
import 'widgets/inspiration_moment_card.dart';

/// 左侧 Tab：心笺（灵感拾遗）
class InspirationFlowPage extends ConsumerWidget {
  const InspirationFlowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final momentsAsync = ref.watch(inspirationMomentsProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '心笺',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '静水流深，思绪如絮。冥想中记下的念头，会在此拾取呈现。',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 13,
                    height: 1.65,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        momentsAsync.when(
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(error.toString())),
          ),
          data: (moments) {
            if (moments.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('尚无记录')),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
              sliver: SliverList.separated(
                itemCount: moments.length,
                separatorBuilder: (_, index) => const SizedBox(height: 28),
                itemBuilder: (context, index) {
                  final moment = moments[index];
                  return InspirationMomentCard(
                    moment: moment,
                    onEdit: () => _showEditSheet(context, ref, moment),
                    onDelete: () => _confirmDelete(context, ref, moment.intent),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

Future<void> _showEditSheet(
  BuildContext context,
  WidgetRef ref,
  InspirationMoment moment,
) async {
  final titleController = TextEditingController(text: moment.title);
  final bodyController = TextEditingController(text: moment.body);

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '编辑心笺',
                      style: GoogleFonts.notoSansSc(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(ctx).pop(false),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleController,
                  textInputAction: TextInputAction.next,
                  decoration: _editDecoration('标题'),
                  style: GoogleFonts.notoSansSc(fontSize: 15),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bodyController,
                  minLines: 5,
                  maxLines: 9,
                  decoration: _editDecoration('正文'),
                  style: GoogleFonts.notoSansSc(fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF516356),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    '保存',
                    style: GoogleFonts.notoSansSc(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  final title = titleController.text;
  final body = bodyController.text;
  titleController.dispose();
  bodyController.dispose();

  if (saved != true || !context.mounted) return;
  if (title.trim().isEmpty && body.trim().isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('心笺不能为空')));
    return;
  }

  await ref
      .read(intentControllerProvider.notifier)
      .updateJournal(intent: moment.intent, title: title, body: body);
  if (!context.mounted) return;
  final state = ref.read(intentControllerProvider);
  if (state.hasError) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(state.error.toString())));
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  FlowIntent intent,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        '删除心笺',
        style: GoogleFonts.notoSansSc(fontWeight: FontWeight.w500),
      ),
      content: Text(
        '这条心笺会从列表中移除。',
        style: GoogleFonts.notoSansSc(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('取消', style: GoogleFonts.notoSansSc()),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            '删除',
            style: GoogleFonts.notoSansSc(color: const Color(0xFF9B4D45)),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(intentControllerProvider.notifier).deleteJournal(intent);
}

InputDecoration _editDecoration(String hint) {
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
