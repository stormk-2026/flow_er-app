import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/splash_colors.dart';
import '../shell/main_scaffold.dart';
import 'widgets/lotus_divider.dart';
import 'widgets/zen_ripple.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 3), _goHome);
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, a1, a2) => const MainScaffold(),
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (context, animation, a2, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [SplashColors.backgroundTop, SplashColors.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _goHome,
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  const ZenRipple(size: 240),
                  const SizedBox(height: 28),
                  Text(
                    '流  境',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 2,
                      color: SplashColors.title,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const LotusDivider(width: 220),
                  const Spacer(flex: 4),
                  Text(
                    '万籁俱寂，心生欢喜。',
                    style: GoogleFonts.notoSansSc(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: SplashColors.quote,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
