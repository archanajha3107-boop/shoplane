import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const ShopLaneApp());
}

class ShopLaneApp extends StatelessWidget {
  const ShopLaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShopLane',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F7B6C),
          primary: const Color(0xFF0F7B6C),
          secondary: const Color(0xFFE85A2B),
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F1EF),
        fontFamily: 'Mukta',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}