import 'package:flow_er/core/i18n/ui_text.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// 全局顶栏：左昵称（已登录）· 中品牌 · 右设置
/// 未登录时左侧和右侧均隐藏，仅显示品牌居中。
class FlowAppBar extends StatelessWidget {
  const FlowAppBar({
    super.key,
    this.nickname,
    this.onIdentityTap,
    this.onSettingsTap,
  });

  final String? nickname;
  final VoidCallback? onIdentityTap;
  final VoidCallback? onSettingsTap;

  bool get _isLoggedIn => nickname != null && nickname!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _isLoggedIn ? 340 : 118),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final sideWidth = (constraints.maxWidth * 0.28).clamp(
                      44.0,
                      96.0,
                    );
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: Row(
                            children: [
                              SizedBox(
                                width: sideWidth,
                                child: _isLoggedIn
                                    ? Padding(
                                        padding: const EdgeInsets.only(
                                          left: 14,
                                        ),
                                        child: _NicknameText(
                                          label: nickname!.trim(),
                                          onTap: onIdentityTap,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const Expanded(child: SizedBox.shrink()),
                              SizedBox(
                                width: sideWidth,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _isLoggedIn
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: _SettingsIconButton(
                                            onTap: onSettingsTap,
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Center(child: _BrandTitle()),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '流'.tr,
          style: GoogleFonts.notoSerifSc(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 2),
        Image.asset(
          'assets/icons/flow_er_icon_trans.png',
          width: 18,
          height: 18,
        ),
        const SizedBox(width: 2),
        Text(
          '境'.tr,
          style: GoogleFonts.notoSerifSc(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _NicknameText extends StatelessWidget {
  const _NicknameText({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSansSc(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsIconButton extends StatelessWidget {
  const _SettingsIconButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.tune_rounded, size: 22, color: AppColors.navIcon),
        ),
      ),
    );
  }
}
