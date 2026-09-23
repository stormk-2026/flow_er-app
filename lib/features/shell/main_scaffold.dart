import 'package:flow_er/core/i18n/ui_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_dialog.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../analytics/zen_analytics_page.dart';
import '../auth/auth_page.dart';
import '../inspiration/inspiration_flow_page.dart';
import '../settings/settings_page.dart';
import '../state/state_perception_page.dart';
import 'widgets/flow_app_bar.dart';
import 'widgets/guest_shell_blur_overlay.dart';
import 'widgets/zen_capsule_nav.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  MainTab _current = MainTab.state;
  bool _shellHidden = false;
  bool _didSyncForRestoredSession = false;
  DateTime? _lastBackPressedAt;

  void _setShellHidden(bool hide) {
    if (_shellHidden == hide) return;
    setState(() => _shellHidden = hide);
  }

  void _onIdentityTap(BuildContext context) {
    final session = ref.read(authProvider).valueOrNull;
    if (session == null) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AuthPage()));
      return;
    }
    _showLogoutDialog(context, session.nickname);
  }

  Future<void> _showLogoutDialog(BuildContext context, String nickname) async {
    final confirmed = await showGlassDialog(
      context: context,
      title: '退出登录'.tr,
      message: UiText.english
          ? 'Sign out of $nickname?'
          : '是否退出当前账号（$nickname）？',
      confirmLabel: '退出登录'.tr,
      icon: Icons.logout_rounded,
    );

    if (confirmed == true && mounted) {
      ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider).valueOrNull;
    final settings = ref.watch(settingsProvider);
    final themeMode = settings.themeMode;
    final themeKey = '${themeMode.name}-${AppColors.background.toARGB32()}';
    final isLoggedIn = session != null;

    if (isLoggedIn && !_didSyncForRestoredSession) {
      _didSyncForRestoredSession = true;
      Future.microtask(_syncOnLogin);
    }

    ref.listen<AsyncValue<AuthSession?>>(authProvider, (previous, next) {
      final wasLoggedIn = previous?.valueOrNull != null;
      final isNowLoggedIn = next.valueOrNull != null;
      if (!wasLoggedIn && isNowLoggedIn) {
        _didSyncForRestoredSession = true;
        // 刚登录：拉取远端心笺
        _syncOnLogin();
      }
      if (wasLoggedIn && next.valueOrNull == null) {
        _didSyncForRestoredSession = false;
        setState(() {
          _current = MainTab.state;
          _shellHidden = false;
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              top: !_shellHidden,
              bottom: !_shellHidden,
              left: !_shellHidden,
              right: !_shellHidden,
              child: Column(
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: double.infinity,
                      height: _shellHidden ? 0 : null,
                      child: AnimatedOpacity(
                        opacity: _shellHidden ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 220),
                        child: IgnorePointer(
                          ignoring: _shellHidden,
                          child: FlowAppBar(
                            key: ValueKey('appbar-$themeKey'),
                            nickname: session?.nickname,
                            onIdentityTap: isLoggedIn
                                ? () => _onIdentityTap(context)
                                : null,
                            onSettingsTap: isLoggedIn
                                ? () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SettingsPage(),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        IndexedStack(
                          index: isLoggedIn
                              ? _current.index
                              : MainTab.state.index,
                          children: [
                            if (isLoggedIn)
                              InspirationFlowPage(
                                key: ValueKey('inspiration-$themeKey'),
                                isActive:
                                    _current == MainTab.inspiration &&
                                    !_shellHidden,
                              )
                            else
                              const SizedBox.shrink(),
                            StatePerceptionPage(
                              key: ValueKey('state-$themeKey'),
                              isActive: isLoggedIn && _current == MainTab.state,
                              featuresEnabled: isLoggedIn,
                              onShellHide: _setShellHidden,
                            ),
                            if (isLoggedIn)
                              ZenAnalyticsPage(
                                key: ValueKey('analytics-$themeKey'),
                              )
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 20,
                          child: AnimatedOpacity(
                            opacity: _shellHidden ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 500),
                            child: IgnorePointer(
                              ignoring: _shellHidden || !isLoggedIn,
                              child: Center(
                                child: ZenCapsuleNav(
                                  key: ValueKey('nav-$themeKey'),
                                  current: _current,
                                  onChanged: (tab) {
                                    setState(() {
                                      _current = tab;
                                      if (tab != MainTab.state) {
                                        _shellHidden = false;
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // The glass covers the viewport, not just the page's safe area.
            if (!isLoggedIn)
              GuestShellBlurOverlay(
                onLoginTap: () => _onIdentityTap(context),
                languageActionLabel: settings.language == AppLanguage.chinese
                    ? 'English'
                    : '中文',
                onLanguageTap: () => ref
                    .read(settingsProvider.notifier)
                    .setLanguage(
                      settings.language == AppLanguage.chinese
                          ? AppLanguage.english
                          : AppLanguage.chinese,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleSystemBack() {
    if (_shellHidden) {
      _showBackHint('此刻仍在心流中，先三击圆点退出心流。'.tr);
      return;
    }

    final now = DateTime.now();
    final shouldExit =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) < const Duration(seconds: 2);
    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    _showBackHint('再按一次退出应用'.tr);
  }

  void _showBackHint(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Future<void> _syncOnLogin() async {
    await ref.read(intentSyncServiceProvider).syncOnLogin();
    await ref.read(focusSessionSyncServiceProvider).syncOnLogin();
    if (!mounted) return;
    invalidateAnalyticsWidgetProviders(ref);
  }
}
