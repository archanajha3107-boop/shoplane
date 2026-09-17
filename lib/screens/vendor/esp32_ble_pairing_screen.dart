// esp32_ble_pairing_screen.dart
// Vendor-side: scans for the ESP32 advertising as "ShopLane-Setup", connects
// over Bluetooth, and sends WiFi credentials + vendorId ONCE. After this,
// the device never needs Bluetooth again — it boots straight to WiFi.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const String _serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String _characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

class Esp32BlePairingScreen extends StatefulWidget {
  final String vendorId;
  const Esp32BlePairingScreen({super.key, required this.vendorId});

  @override
  State<Esp32BlePairingScreen> createState() => _Esp32BlePairingScreenState();
}

class _Esp32BlePairingScreenState extends State<Esp32BlePairingScreen> {
  final List<ScanResult> _foundDevices = [];
  bool _scanning = false;
  BluetoothDevice? _connectingTo;
  bool _sending = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() { _scanning = true; _foundDevices.clear(); });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));

    FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == "ShopLane-Setup" &&
            !_foundDevices.any((d) => d.device.remoteId == r.device.remoteId)) {
          setState(() => _foundDevices.add(r));
        }
      }
    });

    await Future.delayed(const Duration(seconds: 8));
    setState(() => _scanning = false);
  }

  Future<void> _connectAndPair(BluetoothDevice device) async {
    setState(() { _connectingTo = device; _status = 'Connecting...'; });

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      final services = await device.discoverServices();

      final targetService = services.firstWhere((s) => s.uuid.str == _serviceUuid);
      final characteristic = targetService.characteristics.firstWhere((c) => c.uuid.str == _characteristicUuid);

      if (mounted) {
        final credentials = await _showWifiCredentialsDialog(context);
        if (credentials == null) {
          setState(() { _connectingTo = null; _status = ''; });
          return;
        }

        setState(() { _sending = true; _status = 'Sending WiFi details to device...'; });

        final payload = jsonEncode({
          'ssid': credentials['ssid'],
          'password': credentials['password'],
          'vendorId': widget.vendorId,
        });

        await characteristic.write(utf8.encode(payload));

        setState(() { _sending = false; _status = 'Sent! Device is restarting and connecting to WiFi.'; });

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() { _status = 'Pairing failed: $e'; _sending = false; });
    }
  }

  Future<Map<String, String>?> _showWifiCredentialsDialog(BuildContext context) {
    final ssidController = TextEditingController();
    final passwordController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter Shop WiFi Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ssidController, decoration: const InputDecoration(labelText: 'WiFi Name (SSID)')),
            const SizedBox(height: 12),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'WiFi Password')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ssidController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, {
                'ssid': ssidController.text.trim(),
                'password': passwordController.text,
              });
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Hardware'), backgroundColor: const Color(0xFF0F7B6C)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Make sure your ShopLane device is powered on and nearby.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            if (_scanning) const Row(children: [CircularProgressIndicator(strokeWidth: 2), SizedBox(width: 12), Text('Scanning...')]),
            if (_status.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_status)),
            Expanded(
              child: _foundDevices.isEmpty && !_scanning
                  ? const Center(child: Text('No device found. Make sure it\'s powered on and try again.'))
                  : ListView.builder(
                      itemCount: _foundDevices.length,
                      itemBuilder: (context, i) {
                        final device = _foundDevices[i].device;
                        return ListTile(
                          leading: const Icon(Icons.bluetooth),
                          title: Text(device.platformName.isEmpty ? 'ShopLane Device' : device.platformName),
                          trailing: _connectingTo == device && (_sending)
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : ElevatedButton(onPressed: () => _connectAndPair(device), child: const Text('Pair')),
                        );
                      },
                    ),
            ),
            if (!_scanning)
              TextButton.icon(icon: const Icon(Icons.refresh), label: const Text('Scan Again'), onPressed: _startScan),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}