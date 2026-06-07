import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/app_database.dart';
import '../../providers/app_providers.dart';
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
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '静水流深，思绪如絮。冥想中记下的念头，会在此拾取呈现。',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 13,
                    height: 1.65,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.72),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '双击心笺卡片，听见背后的回响',
                      style: GoogleFonts.notoSansSc(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
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
                separatorBuilder: (_, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final moment = moments[index];
                  return InspirationMomentCard(
                    key: ValueKey(moment.stableKey),
                    moment: moment,
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
