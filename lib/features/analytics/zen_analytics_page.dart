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
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
          sliver: SliverToBoxAdapter(
            child: _PeriodPicker(
              period: _period,
              onChanged: (period) => setState(() => _period = period),
            ),
          ),
        ),
        statsAsync.when(
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: _ErrorState(
              message: '沉淀数据暂时不可用',
              onRetry: () => ref.invalidate(analyticsStatsProvider(_period)),
            ),
          ),
          data: (stats) {
            final cards = _buildCards(context, stats, portraitAsync);
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 124),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => cards[index],
                  childCount: cards.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildCards(
    BuildContext context,
    AnalyticsStats stats,
    AsyncValue<AnalyticsPortrait> portraitAsync,
  ) {
    final periodLabel = _period.label;
    final portrait = portraitAsync.valueOrNull;
    return [
      _StatCard(
        icon: Icons.hourglass_bottom_outlined,
        value: _hoursText(stats.duration.totalHours),
        unit: '小时',
        label: '总时长',
        hint: periodLabel,
        onTap: () => _showDurationDetail(context, stats),
      ),
      _StatCard(
        icon: Icons.auto_stories_outlined,
        value: '${stats.intents.total}',
        unit: '条',
        label: '心笺收录',
        hint: stats.intents.inspirationPeakHour == null
            ? periodLabel
            : '高发：${stats.intents.inspirationPeakHour}',
        onTap: () => _showIntentDetail(context, stats),
      ),
      _StatCard(
        icon: Icons.self_improvement_outlined,
        value: _scoreText(stats.soulPurity.score),
        unit: stats.soulPurity.score == null ? '' : '%',
        label: '心流纯度',
        hint: stats.sessionCount == 0 ? '尚无专注记录' : '基于 ${stats.sessionCount} 次',
        onTap: () => _showPurityDetail(context, stats),
      ),
      _StatCard(
        icon: Icons.waves_outlined,
        value: _scoreText(stats.awarenessIndex.score),
        unit: stats.awarenessIndex.score == null ? '' : '分',
        label: '觉察指数',
        hint: stats.intents.total == 0 ? '尚无心笺记录' : '心笺深度与多样性',
        onTap: () => _showAwarenessDetail(context, stats),
      ),
      _PortraitCard(
        portrait: portrait?.userPortrait,
        interpretation: portrait?.interpretation,
        loading: portraitAsync.isLoading,
      ),
    ];
  }
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.period, required this.onChanged});

  final AnalyticsPeriod period;
  final ValueChanged<AnalyticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: AnalyticsPeriod.values.map((item) {
          final selected = item == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  item.label,
                  style: GoogleFonts.notoSansSc(
                    fontSize: 12,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
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
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDF2EF), Color(0xFFE8DDD8)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.spa_outlined, size: 21, color: AppColors.navIcon),
          const Spacer(),
          Text(
            loading ? '正在感受…' : (portrait ?? '—'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loading ? '心智质地生成中' : (interpretation ?? '暂无画像'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSansSc(
              fontSize: 11,
              height: 1.45,
              color: AppColors.textSecondary,
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
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

void _showDurationDetail(BuildContext context, AnalyticsStats stats) {
  _showDetailSheet(
    context,
    title: '总时长',
    children: [
      _MetricRow(
        metrics: [
          _Metric('最长', _formatSeconds(stats.duration.longestSeconds)),
          _Metric('平均', _formatSeconds(stats.duration.averageSeconds)),
          _Metric('活跃', '${stats.duration.activeDays} 天'),
          _Metric(
            '频率',
            '${stats.duration.frequencyPerWeek.toStringAsFixed(1)} 次/周',
          ),
        ],
      ),
      _SectionTitle('触发方式'),
      _BarList(
        values: {
          '三击屏幕': stats.duration.byTrigger['triple_tap'] ?? 0,
          '扣置手机': stats.duration.byTrigger['flip_phone'] ?? 0,
        },
      ),
      _SectionTitle('时段分布'),
      _BarList(values: _orderedBuckets(stats.duration.byHourBucket)),
    ],
  );
}

void _showIntentDetail(BuildContext context, AnalyticsStats stats) {
  final deepest = stats.intents.deepestIntent;
  _showDetailSheet(
    context,
    title: '心笺收录',
    children: [
      _SectionTitle('五类分布'),
      _BarList(values: _orderedCategories(stats.intents.byCategory)),
      _SectionTitle('深度最深'),
      _InfoPanel(
        title: deepest?.preview.isNotEmpty == true ? deepest!.preview : '暂无心笺',
        subtitle: deepest == null
            ? '记录会在这里慢慢浮现'
            : '${deepest.length} 字 · ${_formatDate(deepest.createdAt)}',
      ),
      _SectionTitle('心笺时段'),
      _BarList(values: _orderedBuckets(stats.intents.byHourBucket)),
    ],
  );
}

void _showPurityDetail(BuildContext context, AnalyticsStats stats) {
  _showDetailSheet(
    context,
    title: '心流纯度',
    children: [
      _InfoPanel(
        title:
            '${_scoreText(stats.soulPurity.score)}${stats.soulPurity.score == null ? '' : '%'}',
        subtitle:
            '基线：${_formatSeconds(stats.soulPurity.targetSeconds ?? 1500)}',
      ),
      _SectionTitle('因子构成'),
      _BarList(
        values: {
          '时长达成': stats.soulPurity.factorsAvg['duration_score'] ?? 0,
          '完整性': stats.soulPurity.factorsAvg['completion_score'] ?? 0,
          '专注密度': stats.soulPurity.factorsAvg['density_score'] ?? 0,
        },
        maxValue: 60,
      ),
      _SectionTitle('趋势'),
      _TrendLine(points: stats.soulPurity.trend),
    ],
  );
}

void _showAwarenessDetail(BuildContext context, AnalyticsStats stats) {
  final factors = stats.awarenessIndex.factorsAvg;
  _showDetailSheet(
    context,
    title: '觉察指数',
    children: [
      _SectionTitle('因子构成'),
      _BarList(
        values: {
          '心笺数': factors['count_score'] ?? 0,
          '心笺深度': factors['depth_score'] ?? 0,
          '分类多样性': factors['diversity_score'] ?? 0,
          '情绪记录率': (factors['mood_bonus_rate'] ?? 0) * 100,
        },
        maxValue: 40,
      ),
      _SectionTitle('趋势'),
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
                    color: const Color(0xFF516356).withValues(alpha: 0.56),
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
      return const _InfoPanel(title: '暂无趋势', subtitle: '数据积累后会显示曲线');
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
      ..color = const Color(0xFF516356)
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
        Paint()..color = const Color(0xFF516356),
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
  return {for (final key in keys) key: raw[key] ?? 0};
}

Map<String, int> _orderedCategories(Map<String, int> raw) {
  const keys = ['巧思', '体悟', '心绪', '纪事', '摘录'];
  return {for (final key in keys) key: raw[key] ?? 0};
}

String _hoursText(double value) {
  return value < 0.1 ? '0' : value.toStringAsFixed(1);
}

String _scoreText(int? score) => score == null ? '—' : '$score';

String _formatSeconds(int seconds) {
  if (seconds <= 0) return '0 分钟';
  final minutes = seconds ~/ 60;
  final remain = seconds % 60;
  if (minutes <= 0) return '$remain 秒';
  if (remain == 0) return '$minutes 分钟';
  return '$minutes 分 $remain 秒';
}

String _formatDate(DateTime? date) {
  if (date == null) return '未知时间';
  return '${date.month}.${date.day}';
}
