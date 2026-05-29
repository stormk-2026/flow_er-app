import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/focus/time_rewind_copy.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../../providers/time_rewind_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final rewindQuota = ref.watch(timeRewindProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '设置',
          style: GoogleFonts.notoSansSc(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.navIcon,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            '专注',
            style: GoogleFonts.notoSansSc(
              fontSize: 12,
              letterSpacing: 2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsSwitchTile(
            title: '扣置手机进入专注',
            subtitle: '开启后，手机静置于桌面也可进入心流；默认仅轻击三下',
            value: settings.sensorFocusEnabled,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setSensorFocusEnabled(v),
          ),
          const SizedBox(height: 28),
          Text(
            '沉淀',
            style: GoogleFonts.notoSansSc(
              fontSize: 12,
              letterSpacing: 2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          _TimeRewindTile(remainingToday: rewindQuota.remainingToday),
        ],
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _settingsCardDecoration,
      child: Row(
        children: [
          Expanded(child: _SettingsTextBlock(title: title, subtitle: subtitle)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF516356),
            activeTrackColor: const Color(0xFF516356).withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

class _TimeRewindTile extends ConsumerWidget {
  const _TimeRewindTile({required this.remainingToday});

  final int remainingToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRewind = remainingToday > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _settingsCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SettingsTextBlock(
                  title: TimeRewindCopy.title,
                  subtitle: TimeRewindCopy.remainingSubtitle(remainingToday),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  Icons.help_outline_rounded,
                  size: 20,
                  color: AppColors.textMuted.withValues(alpha: 0.85),
                ),
                onPressed: () => _showTimeRewindHelp(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: canRewind
                  ? () => _onRewindTap(context, ref)
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF516356),
                disabledForegroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: canRewind
                        ? const Color(0xFF516356).withValues(alpha: 0.35)
                        : AppColors.divider,
                  ),
                ),
              ),
              child: Text(
                '回溯近 30 分钟内的失败专注',
                style: GoogleFonts.notoSansSc(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRewindTap(BuildContext context, WidgetRef ref) async {
    final count =
        await ref.read(timeRewindProvider.notifier).previewRewindableCount();
    if (!context.mounted) return;

    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('近 30 分钟内没有可回溯的失败专注')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          TimeRewindCopy.title,
          style: GoogleFonts.notoSansSc(fontWeight: FontWeight.w500),
        ),
        content: Text(
          TimeRewindCopy.confirmMessage(count),
          style: GoogleFonts.notoSansSc(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.6,
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
              '回溯',
              style: GoogleFonts.notoSansSc(color: const Color(0xFF516356)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final error =
        await ref.read(timeRewindProvider.notifier).rewindRecentFailures();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              '已回溯 $count 次失败专注，不计入统计',
        ),
      ),
    );
  }
}

void _showTimeRewindHelp(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        TimeRewindCopy.title,
        style: GoogleFonts.notoSansSc(fontWeight: FontWeight.w500),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              TimeRewindCopy.intro,
              style: GoogleFonts.notoSansSc(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF516356).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                TimeRewindCopy.zenLine,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansSc(
                  fontSize: 13,
                  height: 1.7,
                  color: const Color(0xFF516356),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('知道了', style: GoogleFonts.notoSansSc()),
        ),
      ],
    ),
  );
}

final _settingsCardDecoration = BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
);

class _SettingsTextBlock extends StatelessWidget {
  const _SettingsTextBlock({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.notoSansSc(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.notoSansSc(
            fontSize: 11,
            height: 1.5,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
