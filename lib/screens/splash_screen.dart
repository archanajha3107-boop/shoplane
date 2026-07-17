import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'role_selection_screen.dart';
import 'customer/customer_home_screen.dart';
import 'vendor/vendor_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _goTo(const RoleSelectionScreen());
      return;
    }

    try {
      final user =
          await AuthService().getUserData(firebaseUser.uid);
      if (!mounted) return;
      if (user == null) {
        _goTo(const RoleSelectionScreen());
      } else if (user.role == 'vendor') {
        _goTo(VendorDashboardScreen(vendor: user));
      } else {
        _goTo(CustomerHomeScreen(customer: user));
      }
    } catch (e) {
      if (!mounted) return;
      _goTo(const RoleSelectionScreen());
    }
  }

  void _goTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F7B6C),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.storefront_rounded,
                size: 48,
                color: Color(0xFF0F7B6C),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'ShopLane',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your neighbourhood, delivered',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}