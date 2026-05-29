import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/splash/splash_page.dart';

void main() {
  runApp(const FlowJingApp());
}

class FlowJingApp extends StatelessWidget {
  const FlowJingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '流境',
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFFF7F7F5),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF737873),
            surface: const Color(0xFFF7F7F5),
          ),
          useMaterial3: true,
        ),
        home: const SplashPage(),
      ),
    );
  }
}
