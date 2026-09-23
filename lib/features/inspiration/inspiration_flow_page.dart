import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_dialog.dart';
import '../../models/app_database.dart';
import '../../providers/app_providers.dart';
import 'widgets/inspiration_moment_card.dart';

/// 左侧 Tab：心笺（灵感拾遗）
class InspirationFlowPage extends ConsumerStatefulWidget {
  const InspirationFlowPage({super.key, this.isActive = true});

  final bool isActive;

  @override
  ConsumerState<InspirationFlowPage> createState() =>
      _InspirationFlowPageState();
}

class _InspirationFlowPageState extends ConsumerState<InspirationFlowPage>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _refreshing = false;
  int _pollsRemaining = 24;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleRefresh(immediate: true);
  }

  @override
  void didUpdateWidget(covariant InspirationFlowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _pollsRemaining = 24;
      _scheduleRefresh(immediate: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _pollsRemaining = 24;
    _scheduleRefresh(immediate: true);
  }

  void _scheduleRefresh({bool immediate = false}) {
    _refreshTimer?.cancel();
    if (!mounted || !widget.isActive || !_foreground || _pollsRemaining <= 0) {
      return;
    }
    _refreshTimer = Timer(
      immediate ? Duration.zero : const Duration(seconds: 5),
      () async {
        if (!mounted) return;
        final moments = ref.read(inspirationMomentsProvider).valueOrNull;
        if (immediate ||
            moments == null ||
            moments.any((m) => !m.hasAiComment)) {
          _pollsRemaining--;
          await _refresh();
        }
        if (mounted) {
          final latest = ref.read(inspirationMomentsProvider).valueOrNull;
          if (latest == null || latest.any((m) => !m.hasAiComment)) {
            _scheduleRefresh();
          }
        }
      },
    );
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await ref.read(intentSyncServiceProvider).refreshSnapshot();
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final momentsAsync = ref.watch(inspirationMomentsProvider);
    final pending = ref.watch(pendingIntentCountProvider).valueOrNull;

    return RefreshIndicator(
      onRefresh: () async {
        _pollsRemaining = 24;
        await _refresh();
        if (mounted) _scheduleRefresh();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                  if (pending != null && pending > 0)
                    Text(
                      '有 $pending 项仅保存在本机或等待同步，请联网后下拉重试',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
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
                      Flexible(
                        child: Text(
                          '绿角可翻转 · 长按可删除 · 下拉刷新回响',
                          style: GoogleFonts.notoSansSc(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.76,
                            ),
                          ),
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
                      onDelete: () =>
                          _confirmDelete(context, ref, moment.intent),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  FlowIntent intent,
) async {
  final confirmed = await showGlassDialog(
    context: context,
    title: '删除心笺',
    message: '这条心笺及背面的回响将从列表中移除。\n确定要删除吗？',
    confirmLabel: '删除心笺',
    icon: Icons.delete_outline_rounded,
    destructive: true,
  );
  if (confirmed != true || !context.mounted) return;
  await ref.read(intentControllerProvider.notifier).deleteJournal(intent);
}
