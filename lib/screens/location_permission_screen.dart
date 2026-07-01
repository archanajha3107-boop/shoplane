import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'customer/customer_signup_screen.dart';

class LocationPermissionScreen extends StatefulWidget {
  final String role;
  const LocationPermissionScreen({super.key, required this.role});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState
    extends State<LocationPermissionScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Location permission is permanently denied. Please enable it from app settings.';
      });
      return;
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      setState(() => _isLoading = false);
      if (widget.role == 'customer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const CustomerSignupScreen()),
        );
      }
      // Vendor navigation will be added after vendor signup screen is built
    }
  }

  Future<void> _openSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F7B6C).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 64,
                  color: Color(0xFF0F7B6C),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Allow Location Access',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C2C2C),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'ShopLane uses your location to show nearby vendors and help them deliver to you accurately. This is required to use the app.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                        color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _requestPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F7B6C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Allow Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (_errorMessage != null)
                TextButton(
                  onPressed: _openSettings,
                  child: const Text(
                    'Open App Settings',
                    style: TextStyle(
                      color: Color(0xFFE85A2B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}