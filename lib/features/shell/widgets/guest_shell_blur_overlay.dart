import 'package:flow_er/core/i18n/ui_text.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/greeting/home_greeting.dart';
import '../../../core/theme/app_colors.dart';

/// 未登录时覆盖整个屏幕；玻璃不受安全区裁切，登录入口保留安全边距。
class GuestShellBlurOverlay extends StatelessWidget {
  const GuestShellBlurOverlay({
    super.key,
    required this.onLoginTap,
    this.languageActionLabel,
    this.onLanguageTap,
  });

  final VoidCallback onLoginTap;
  final String? languageActionLabel;
  final VoidCallback? onLanguageTap;

  @override
  Widget build(BuildContext context) {
    final invite = HomeGreeting.guestInvite();

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 模糊背景层——吸收所有点击，防止误触底层
          AbsorbPointer(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: ColoredBox(
                  key: const ValueKey('guest-glass-surface'),
                  color: AppColors.guestGlassSurface,
                ),
              ),
            ),
          ),
          // 中央文案——透出点击，引导登录
          SafeArea(
            child: Center(
              child: GestureDetector(
                onTap: onLoginTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        invite,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSansSc(
                          fontSize: 15,
                          height: 1.7,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.textMuted.withValues(alpha: 0.35),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '轻触，入静'.tr,
                          style: GoogleFonts.notoSansSc(
                            fontSize: 12,
                            letterSpacing: 2,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (onLanguageTap != null && languageActionLabel != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20, top: 8),
                  child: TextButton(
                    onPressed: onLanguageTap,
                    child: Text(
                      languageActionLabel!,
                      style: GoogleFonts.notoSansSc(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
