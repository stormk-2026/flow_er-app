import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/day_night_theme.dart';

/// Shared confirmation/help surface. Dismissal is never confirmation.
Future<bool?> showGlassDialog({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  String confirmLabel = '确定',
  String? cancelLabel = '取消',
  IconData icon = Icons.spa_outlined,
  bool destructive = false,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(
      0xFF101B16,
    ).withValues(alpha: isNightTheme ? 0.58 : 0.28),
    transitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) => GlassDialog(
      title: title,
      message: message,
      content: content,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      destructive: destructive,
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final progress = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: progress,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(progress),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(progress),
            child: child,
          ),
        ),
      );
    },
  );
}

class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.confirmLabel = '确定',
    this.cancelLabel = '取消',
    this.icon = Icons.spa_outlined,
    this.destructive = false,
  });

  final String title;
  final String? message;
  final Widget? content;
  final String confirmLabel;
  final String? cancelLabel;
  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final night = isNightTheme;
    final accent = destructive
        ? (night ? const Color(0xFFE0A398) : const Color(0xFF98554C))
        : AppColors.primaryAction;
    final actionColor = destructive
        ? (night ? const Color(0xFFB8786D) : const Color(0xFF98554C))
        : (night ? const Color(0xFFA6BAAC) : const Color(0xFF516B5A));
    final bodyColor = night ? const Color(0xFFC2C8BB) : const Color(0xFF596158);

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF14241B,
                ).withValues(alpha: night ? 0.3 : 0.13),
                blurRadius: 48,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: night
                        ? [
                            const Color(0xFF303B32).withValues(alpha: 0.9),
                            const Color(0xFF1A241E).withValues(alpha: 0.88),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.9),
                            const Color(0xFFEAF0E8).withValues(alpha: 0.78),
                          ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: night ? 0.18 : 0.8),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: night ? 0.13 : 0.07),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.13),
                          ),
                        ),
                        child: Icon(icon, size: 21, color: accent),
                      ),
                      const SizedBox(height: 18),
                      Semantics(
                        namesRoute: true,
                        header: true,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSerifSc(
                            fontSize: 22,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (message != null)
                        Text(
                          message!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansSc(
                            fontSize: 14,
                            height: 1.8,
                            color: bodyColor,
                          ),
                        ),
                      ?content,
                      const SizedBox(height: 26),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final vertical =
                              constraints.maxWidth < 260 ||
                              MediaQuery.textScalerOf(context).scale(14) > 19;
                          final confirm = FilledButton(
                            key: const ValueKey('glass-dialog-confirm'),
                            onPressed: () => Navigator.of(context).pop(true),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 13,
                              ),
                              backgroundColor: actionColor,
                              foregroundColor: night
                                  ? const Color(0xFF142119)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              textStyle: GoogleFonts.notoSansSc(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: Text(
                              confirmLabel,
                              textAlign: TextAlign.center,
                            ),
                          );
                          if (cancelLabel == null) return confirm;
                          final cancel = OutlinedButton(
                            key: const ValueKey('glass-dialog-cancel'),
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 13,
                              ),
                              foregroundColor: bodyColor,
                              backgroundColor: Colors.white.withValues(
                                alpha: night ? 0.025 : 0.18,
                              ),
                              side: BorderSide(
                                color: accent.withValues(alpha: 0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              textStyle: GoogleFonts.notoSansSc(fontSize: 14),
                            ),
                            child: Text(
                              cancelLabel!,
                              textAlign: TextAlign.center,
                            ),
                          );
                          if (vertical) {
                            return Column(
                              children: [
                                cancel,
                                const SizedBox(height: 10),
                                confirm,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: cancel),
                              const SizedBox(width: 12),
                              Expanded(child: confirm),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
