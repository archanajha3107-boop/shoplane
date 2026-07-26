import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'vendor_dashboard_screen.dart';
import 'product_catalog_screen.dart';
import 'voice_product_screen.dart';
import 'vendor_settings_screen.dart';

class VendorShellScreen extends StatefulWidget {
  final UserModel vendor;
  const VendorShellScreen({super.key, required this.vendor});

  @override
  State<VendorShellScreen> createState() => _VendorShellScreenState();
}

class _VendorShellScreenState extends State<VendorShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      VendorDashboardScreen(vendor: widget.vendor),
      ProductCatalogScreen(vendorId: widget.vendor.uid),
      VoiceProductScreen(vendorId: widget.vendor.uid),
      VendorSettingsScreen(vendor: widget.vendor),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE85A2B).withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFFE85A2B)), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded, color: Color(0xFFE85A2B)), label: 'Products'),
          NavigationDestination(icon: Icon(Icons.mic_none_rounded), selectedIcon: Icon(Icons.mic_rounded, color: Color(0xFFE85A2B)), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFFE85A2B)), label: 'Settings'),
        ],
      ),
    );
  }
}