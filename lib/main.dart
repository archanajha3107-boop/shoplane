import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/splash_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Background message handler
  FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);

  // Request notification permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Foreground notification handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // App is open — the dashboard StreamBuilder will update automatically
    // No additional handling needed for vendor dashboard
  });

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
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}