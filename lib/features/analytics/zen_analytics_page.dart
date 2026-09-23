import 'package:flow_er/core/i18n/ui_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/analytics/analytics_service.dart';

class ZenAnalyticsPage extends ConsumerStatefulWidget {
  const ZenAnalyticsPage({super.key});

  @override
  ConsumerState<ZenAnalyticsPage> createState() => _ZenAnalyticsPageState();
}

class _ZenAnalyticsPageState extends ConsumerState<ZenAnalyticsPage> {
  AnalyticsPeriod _period = AnalyticsPeriod.thirtyDays;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(analyticsStatsProvider(_period));
    final portraitAsync = ref.watch(analyticsPortraitProvider(_period));

    return CustomScrollView(
      slivers: [
        statsAsync.when(
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: _ErrorState(
              message: '沉淀数据暂时不可用'.tr,
              onRetry: () => ref.invalidate(analyticsStatsProvider(_period)),
            ),
          ),
          data: (stats) {
            final statCards = _buildStatCards(context, stats);
            final portrait = portraitAsync.valueOrNull;
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 124),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '沉淀'.tr,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '山静日长，万象归心。专注、心笺与觉察，会在此沉入清晰的纹理。'.tr,
                              style: GoogleFonts.notoSansSc(
                                fontSize: 13,
                                height: 1.65,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _PeriodMenu(
                        period: _period,
                        onChanged: (period) => setState(() => _period = period),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _PortraitCard(
                    portrait: portrait?.userPortrait,
                    interpretation: portrait?.interpretation,
                    loading: portraitAsync.isLoading,
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: statCards,
                  ),
                ]),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildStatCards(BuildContext context, AnalyticsStats stats) {
    final periodLabel = _period.label.tr;
    return [
      _StatCard(
        icon: Icons.hourglass_bottom_outlined,
        value: _hoursText(stats.duration.totalHours),
        unit: '小时'.tr,
        label: '总时长'.tr,
        hint: periodLabel,
        onTap: () => _showDurationDetail(context, stats),
      ),
      _StatCard(
        icon: Icons.auto_stories_outlined,
        value: '${stats.intents.total}',
        unit: '条'.tr,
        label: '心笺收录'.tr,
        hint: stats.intents.inspirationPeakHour == null
            ? periodLabel
            : UiText.english
            ? 'Peak: ${stats.intents.inspirationPeakHour?.tr ?? ''}'
            : '高发：${stats.intents.inspirationPeakHour}',
        onTap: () => _showIntentDetail(context, stats),
      ),
      _StatCard(
        icon: Icons.self_improvement_outlined,
        value: _scoreText(stats.soulPurity.score),
        unit: stats.soulPurity.score == null ? '' : '%',
        label: '心流纯度'.tr,
        hint: stats.sessionCount == 0
            ? '尚无专注记录'.tr
            : (UiText.english
                  ? 'Based on ${stats.sessionCount} sessions'
                  : '基于 ${stats.sessionCount} 次'),
        onTap: () => _showPurityDetail(context, stats),
      ),
      _StatCard(
        icon: Icons.waves_outlined,
        value: _scoreText(stats.awarenessIndex.score),
        unit: stats.awarenessIndex.score == null ? '' : '分'.tr,
        label: '觉察指数'.tr,
        hint: stats.intents.total == 0 ? '尚无心笺记录'.tr : '心笺深度与多样性'.tr,
        onTap: () => _showAwarenessDetail(context, stats),
      ),
    ];
  }
}

class _PeriodMenu extends StatelessWidget {
  const _PeriodMenu({required this.period, required this.onChanged});

  final AnalyticsPeriod period;
  final ValueChanged<AnalyticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AnalyticsPeriod>(
      tooltip: '切换周期'.tr,
      initialValue: period,
      color: AppColors.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onChanged,
      itemBuilder: (context) => AnalyticsPeriod.values.map((item) {
        return PopupMenuItem(
          value: item,
          child: Text(
            item.label.tr,
            style: GoogleFonts.notoSansSc(fontSize: 13),
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.glassSurface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              period.label.tr,
              style: GoogleFonts.notoSansSc(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    this.hint,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.glassSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 21, color: AppColors.navIcon),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: GoogleFonts.notoSansSc(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansSc(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansSc(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PortraitCard extends StatelessWidget {
  const _PortraitCard({
    required this.portrait,
    required this.interpretation,
    required this.loading,
  });

  final String? portrait;
  final String? interpretation;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.statGradient,
        ),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Icon(Icons.spa_outlined, size: 22, color: AppColors.navIcon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading ? '正在感受…'.tr : (portrait ?? '—'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 29,
                    height: 1.12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loading ? '心智质地生成中'.tr : (interpretation ?? '暂无画像'.tr),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansSc(
                    fontSize: 12,
                    height: 1.48,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: GoogleFonts.notoSansSc(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: Text('重试'.tr)),
        ],
      ),
    );
  }
}

void _showDurationDetail(BuildContext context, AnalyticsStats stats) {
  _showDetailSheet(
    context,
    title: '总时长'.tr,
    children: [
      _MetricRow(
        metrics: [
          _Metric('最长'.tr, _formatSeconds(stats.duration.longestSeconds)),
          _Metric('平均'.tr, _formatSeconds(stats.duration.averageSeconds)),
          _Metric('活跃'.tr, '${stats.duration.activeDays} 天'),
          _Metric(
            '频率'.tr,
            UiText.english
                ? '${stats.duration.frequencyPerWeek.toStringAsFixed(1)} / week'
                : '${stats.duration.frequencyPerWeek.toStringAsFixed(1)} 次/周',
          ),
        ],
      ),
      _SectionTitle('触发方式'.tr),
      _BarList(
        values: {
          '三击屏幕'.tr: stats.duration.byTrigger['triple_tap'] ?? 0,
          '扣置手机'.tr: stats.duration.byTrigger['flip_phone'] ?? 0,
        },
      ),
      _SectionTitle('时段分布'.tr),
      _BarList(values: _orderedBuckets(stats.duration.byHourBucket)),
    ],
  );
}

void _showIntentDetail(BuildContext context, AnalyticsStats stats) {
  final deepest = stats.intents.deepestIntent;
  _showDetailSheet(
    context,
    title: '心笺收录'.tr,
    children: [
      _SectionTitle('五类分布'.tr),
      _BarList(values: _orderedCategories(stats.intents.byCategory)),
      _SectionTitle('深度最深'.tr),
      _InfoPanel(
        title: deepest?.preview.isNotEmpty == true
            ? deepest!.preview
            : '暂无心笺'.tr,
        subtitle: deepest == null
            ? '记录会在这里慢慢浮现'.tr
            : UiText.english
            ? '${deepest.length} characters · ${_formatDate(deepest.createdAt)}'
            : '${deepest.length} 字 · ${_formatDate(deepest.createdAt)}',
      ),
      _SectionTitle('心笺时段'.tr),
      _BarList(values: _orderedBuckets(stats.intents.byHourBucket)),
    ],
  );
}

void _showPurityDetail(BuildContext context, AnalyticsStats stats) {
  _showDetailSheet(
    context,
    title: '心流纯度'.tr,
    children: [
      _InfoPanel(
        title:
            '${_scoreText(stats.soulPurity.score)}${stats.soulPurity.score == null ? '' : '%'}',
        subtitle: UiText.english
            ? 'Baseline: ${_formatSeconds(stats.soulPurity.targetSeconds ?? 1500)}'
            : '基线：${_formatSeconds(stats.soulPurity.targetSeconds ?? 1500)}',
      ),
      _SectionTitle('因子构成'.tr),
      _BarList(
        values: {
          '时长达成'.tr: stats.soulPurity.factorsAvg['duration_score'] ?? 0,
          '完整性'.tr: stats.soulPurity.factorsAvg['completion_score'] ?? 0,
          '专注密度'.tr: stats.soulPurity.factorsAvg['density_score'] ?? 0,
        },
        maxValue: 60,
      ),
      _SectionTitle('趋势'.tr),
      _TrendLine(points: stats.soulPurity.trend),
    ],
  );
}

void _showAwarenessDetail(BuildContext context, AnalyticsStats stats) {
  final factors = stats.awarenessIndex.factorsAvg;
  _showDetailSheet(
    context,
    title: '觉察指数'.tr,
    children: [
      _SectionTitle('因子构成'.tr),
      _BarList(
        values: {
          '心笺数'.tr: factors['count_score'] ?? 0,
          '心笺深度'.tr: factors['depth_score'] ?? 0,
          '分类多样性'.tr: factors['diversity_score'] ?? 0,
          '情绪记录率'.tr: (factors['mood_bonus_rate'] ?? 0) * 100,
        },
        maxValue: 40,
      ),
      _SectionTitle('趋势'.tr),
      _TrendLine(points: stats.awarenessIndex.trend),
    ],
  );
}

void _showDetailSheet(
  BuildContext context, {
  required String title,
  required List<Widget> children,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.42,
        maxChildSize: 0.9,
        builder: (context, controller) {
          return Material(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSansSc(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...children,
              ],
            ),
          );
        },
      );
    },
  );
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String value;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: metrics
          .map(
            (metric) => Expanded(
              child: _InfoPanel(title: metric.value, subtitle: metric.label),
            ),
          )
          .toList(),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSansSc(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.notoSansSc(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
      child: Text(
        text,
        style: GoogleFonts.notoSansSc(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _BarList extends StatelessWidget {
  const _BarList({required this.values, this.maxValue});

  final Map<String, num> values;
  final double? maxValue;

  @override
  Widget build(BuildContext context) {
    final peak =
        maxValue ?? values.values.fold<num>(0, (a, b) => a > b ? a : b);
    return Column(
      children: values.entries.map((entry) {
        final ratio = peak <= 0 ? 0.0 : (entry.value / peak).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  entry.key,
                  style: GoogleFonts.notoSansSc(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: AppColors.background,
                    color: AppColors.primaryAction.withValues(alpha: 0.62),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                child: Text(
                  entry.value is int
                      ? '${entry.value}'
                      : entry.value.toStringAsFixed(1),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return _InfoPanel(title: '暂无趋势'.tr, subtitle: '数据积累后会显示曲线'.tr);
    }
    return SizedBox(
      height: 96,
      child: CustomPaint(
        painter: _TrendPainter(points.map((p) => p.score).toList()),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryAction
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      grid,
    );
    if (values.length == 1) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height * (1 - values.first / 100)),
        3,
        Paint()..color = AppColors.primaryAction,
      );
      return;
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height * (1 - (values[i].clamp(0, 100) / 100));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

Map<String, int> _orderedBuckets(Map<String, int> raw) {
  const keys = ['清晨', '上午', '正午', '午后', '夜晚', '深夜'];
  return {for (final key in keys) key.tr: raw[key] ?? 0};
}

Map<String, int> _orderedCategories(Map<String, int> raw) {
  const keys = ['巧思', '体悟', '心绪', '纪事', '摘录'];
  return {for (final key in keys) key.tr: raw[key] ?? 0};
}

String _hoursText(double value) {
  return value < 0.1 ? '0' : value.toStringAsFixed(1);
}

String _scoreText(int? score) => score == null ? '—' : '$score';

String _formatSeconds(int seconds) {
  if (seconds <= 0) return UiText.english ? '0 min' : '0 分钟';
  final minutes = seconds ~/ 60;
  final remain = seconds % 60;
  if (minutes <= 0) return UiText.english ? '${remain}s' : '$remain 秒';
  if (remain == 0) return UiText.english ? '$minutes min' : '$minutes 分钟';
  return UiText.english ? '$minutes min ${remain}s' : '$minutes 分 $remain 秒';
}

String _formatDate(DateTime? date) {
  if (date == null) return '未知时间'.tr;
  return '${date.month}.${date.day}';
}
