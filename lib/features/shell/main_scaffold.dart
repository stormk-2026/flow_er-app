import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '退出登录',
          style: GoogleFonts.notoSansSc(fontWeight: FontWeight.w500),
        ),
        content: Text(
          '是否退出当前账号（$nickname）？',
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
              '退出',
              style: GoogleFonts.notoSansSc(color: const Color(0xFF516356)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider).valueOrNull;
    final themeMode = ref.watch(settingsProvider).themeMode;
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AnimatedOpacity(
                  opacity: _shellHidden ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 500),
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
                      if (!isLoggedIn)
                        GuestShellBlurOverlay(
                          onLoginTap: () => _onIdentityTap(context),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncOnLogin() async {
    await ref.read(intentSyncServiceProvider).syncOnLogin();
    await ref.read(focusSessionSyncServiceProvider).pushPending();
    if (!mounted) return;
    invalidateAnalyticsWidgetProviders(ref);
  }
}
