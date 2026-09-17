import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'shoplane_orders',
    'ShopLane Orders',
    description: 'Order alerts for ShopLane',
    importance: Importance.max,
    playSound: true,
  );

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

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
    return ChangeNotifierProvider(
  create: (_) => CartProvider(),
  child: MaterialApp(
    title: 'ShopLane',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
  seedColor: const Color(0xFF0F7B6C),
  primary: const Color(0xFF0F7B6C),
  secondary: const Color(0xFFE85A2B),
  tertiary: const Color(0xFFC9A227),
),
      scaffoldBackgroundColor: const Color(0xFFF2F1EF),
      fontFamily: 'Mukta',
      useMaterial3: true,
    ),
    home: const SplashScreen(),
  ),
);
  }
}