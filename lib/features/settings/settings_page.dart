import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/focus/time_rewind_copy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_dialog.dart';
import '../../core/theme/day_night_theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/time_rewind_provider.dart';
import 'privacy_page.dart';

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
            '外观',
            style: GoogleFonts.notoSansSc(
              fontSize: 12,
              letterSpacing: 2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          _ThemeModeTile(
            value: settings.themeMode,
            onChanged: (mode) =>
                ref.read(settingsProvider.notifier).setThemeMode(mode),
          ),
          const SizedBox(height: 28),
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
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setSensorFocusEnabled(v),
          ),
          const SizedBox(height: 12),
          _SettingsSwitchTile(
            title: '声音',
            subtitle: '开启后播放点击、心笺与心流白噪音',
            value: settings.soundEnabled,
            onChanged: (v) async {
              await ref.read(settingsProvider.notifier).setSoundEnabled(v);
              await ref.read(appAudioServiceProvider).setEnabled(v);
            },
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
          const SizedBox(height: 24),
          ListTile(
            title: const Text('隐私与数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrivacyPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({required this.value, required this.onChanged});

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _settingsCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SettingsTextBlock(
            title: '界面模式',
            subtitle: '自动会在 06:00 / 18:00 切换，也可以手动指定',
          ),
          const SizedBox(height: 14),
          SegmentedButton<AppThemeMode>(
            segments: AppThemeMode.values
                .map(
                  (mode) => ButtonSegment<AppThemeMode>(
                    value: mode,
                    label: Text(mode.label),
                  ),
                )
                .toList(),
            selected: {value},
            onSelectionChanged: (selection) => onChanged(selection.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? AppColors.textPrimary
                    : AppColors.textSecondary;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? AppColors.accentSoft
                    : Colors.transparent;
              }),
              side: WidgetStatePropertyAll(
                BorderSide(color: AppColors.divider),
              ),
              textStyle: WidgetStatePropertyAll(
                GoogleFonts.notoSansSc(fontSize: 13),
              ),
            ),
          ),
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
          Expanded(
            child: _SettingsTextBlock(title: title, subtitle: subtitle),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryAction,
            activeTrackColor: AppColors.primaryAction.withValues(alpha: 0.35),
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
              onPressed: canRewind ? () => _onRewindTap(context, ref) : null,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryAction,
                disabledForegroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: canRewind
                        ? AppColors.primaryAction.withValues(alpha: 0.35)
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
    final count = await ref
        .read(timeRewindProvider.notifier)
        .previewRewindableCount();
    if (!context.mounted) return;

    if (count == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('近 30 分钟内没有可回溯的失败专注')));
      return;
    }

    final confirmed = await showGlassDialog(
      context: context,
      title: TimeRewindCopy.title,
      message: TimeRewindCopy.confirmMessage(count),
      confirmLabel: '回溯',
      icon: Icons.history_rounded,
    );

    if (confirmed != true || !context.mounted) return;

    final error = await ref
        .read(timeRewindProvider.notifier)
        .rewindRecentFailures();
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? '已回溯 $count 次失败专注，不计入统计')));
  }
}

void _showTimeRewindHelp(BuildContext context) {
  showGlassDialog(
    context: context,
    title: TimeRewindCopy.title,
    message: TimeRewindCopy.intro,
    icon: Icons.history_rounded,
    confirmLabel: '知道了',
    cancelLabel: null,
    content: Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primaryAction.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryAction.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          TimeRewindCopy.zenLine,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSerifSc(
            fontSize: 13,
            height: 1.8,
            color: AppColors.primaryAction,
          ),
        ),
      ),
    ),
  );
}

BoxDecoration get _settingsCardDecoration => BoxDecoration(
  color: AppColors.glassSurface,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: AppColors.glassBorder),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 14,
      offset: const Offset(0, 5),
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
