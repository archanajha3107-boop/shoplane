import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:http/http.dart' as http;

class Esp32SetupScreen extends StatefulWidget {
  final String vendorId;
  const Esp32SetupScreen({super.key, required this.vendorId});

  @override
  State<Esp32SetupScreen> createState() => _Esp32SetupScreenState();
}

class _Esp32SetupScreenState extends State<Esp32SetupScreen> {
  // Step tracking
  // 0 = scan, 1 = pin entry, 2 = wifi credentials, 3 = done
  int _step = 0;

  List<WiFiAccessPoint> _devices = [];
  WiFiAccessPoint? _selectedDevice;
  bool _scanning = false;
  bool _loading  = false;
  String _status = 'Tap Scan to find your ShopLane device';
  String _deviceId = '';

  final _pinController      = TextEditingController();
  final _ssidController     = TextEditingController();
  final _passwordController = TextEditingController();

  static const String _esp32Ip = 'http://192.168.4.1';

  // ── Step 0: Scan for ShopLane WiFi networks ────────────────
  Future<void> _scan() async {
    setState(() { _scanning = true; _status = 'Scanning for ShopLane devices...'; });

    final can = await WiFiScan.instance.canStartScan(askPermissions: true);
    if (can != CanStartScan.yes) {
      setState(() { _scanning = false; _status = 'Location permission required to scan WiFi'; });
      return;
    }

    await WiFiScan.instance.startScan();
    await Future.delayed(const Duration(seconds: 3));

    final result = await WiFiScan.instance.getScannedResults();
    final shopLaneDevices = result
        .where((ap) => (ap.ssid ?? '').startsWith('ShopLane-'))
        .toList();

    setState(() {
      _scanning = false;
      _devices  = shopLaneDevices;
      _status   = shopLaneDevices.isEmpty
          ? 'No ShopLane devices found.\nMake sure your device is powered on with no saved WiFi.'
          : 'Found ${shopLaneDevices.length} device(s). Tap to select.';
    });
  }

  // ── Step 1: User selected a device → ask for PIN ──────────
  void _selectDevice(WiFiAccessPoint ap) {
    final ssid = ap.ssid ?? '';
    _deviceId = ssid.replaceFirst('ShopLane-', '');
    setState(() {
      _selectedDevice = ap;
      _step   = 1;
      _status = 'Connect your phone to "$ssid" WiFi first, then enter the PIN shown on the device screen.';
    });
  }

  // ── Step 2: Verify PIN with ESP32 ─────────────────────────
  Future<void> _verifyPin() async {
    if (_pinController.text.length != 4) {
      setState(() => _status = 'Enter the 4-digit PIN shown on the OLED screen');
      return;
    }

    setState(() { _loading = true; _status = 'Verifying PIN...'; });

    try {
      final response = await http.post(
        Uri.parse('$_esp32Ip/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pin': _pinController.text}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['verified'] == true) {
        setState(() {
          _step   = 2;
          _status = 'PIN verified! Now enter your shop\'s WiFi details.';
        });
      } else {
        setState(() => _status = 'Wrong PIN. Check the OLED screen on your device.');
      }
    } catch (e) {
      setState(() => _status = 'Could not reach device.\nMake sure you\'re connected to the ShopLane WiFi network.');
    }

    setState(() => _loading = false);
  }

  // ── Step 3: Send WiFi credentials to ESP32 ────────────────
  Future<void> _sendCredentials() async {
    if (_ssidController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _status = 'Enter your WiFi name and password');
      return;
    }

    setState(() { _loading = true; _status = 'Sending credentials to device...'; });

    try {
      final response = await http.post(
        Uri.parse('$_esp32Ip/configure'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ssid':     _ssidController.text.trim(),
          'password': _passwordController.text,
          'vendorId': widget.vendorId,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _step   = 3;
          _status = 'Done! Your device is restarting and will connect to WiFi automatically.';
        });
      } else {
        setState(() => _status = 'Device returned an error. Try again.');
      }
    } catch (e) {
      // ESP32 restarts immediately after saving — connection drop is expected
      setState(() {
        _step   = 3;
        _status = 'Credentials sent! Device is restarting.\nReconnect your phone to your normal WiFi.';
      });
    }

    setState(() => _loading = false);
  }

  // ── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('Set Up Hardware Device'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            _buildProgressBar(),
            const SizedBox(height: 24),

            // Status card
            _buildStatusCard(),
            const SizedBox(height: 24),

            // Step content
            if (_step == 0) _buildScanStep(),
            if (_step == 1) _buildPinStep(),
            if (_step == 2) _buildWifiStep(),
            if (_step == 3) _buildDoneStep(),

            const SizedBox(height: 32),

            // How it works
            if (_step == 0) _buildInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final steps = ['Find Device', 'Enter PIN', 'WiFi Setup', 'Done'];
    return Row(
      children: List.generate(steps.length, (i) {
        final done    = i < _step;
        final current = i == _step;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: done
                          ? const Color(0xFF0F7B6C)
                          : current
                              ? const Color(0xFFE85A2B)
                              : Colors.grey.shade300,
                      child: done
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : Text('${i+1}',
                              style: TextStyle(
                                  color: current ? Colors.white : Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 4),
                    Text(steps[i],
                        style: TextStyle(
                            fontSize: 10,
                            color: current
                                ? const Color(0xFFE85A2B)
                                : done
                                    ? const Color(0xFF0F7B6C)
                                    : Colors.grey),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < _step
                        ? const Color(0xFF0F7B6C)
                        : Colors.grey.shade300,
                    margin: const EdgeInsets.only(bottom: 20),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _step == 3
            ? const Color(0xFF0F7B6C).withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _step == 3
              ? const Color(0xFF0F7B6C)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _step == 3
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            color: _step == 3
                ? const Color(0xFF0F7B6C)
                : const Color(0xFFE85A2B),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_status,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ── Step 0 UI: Scan + device list ─────────────────────────
  Widget _buildScanStep() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.wifi_find_rounded),
            label: Text(_scanning ? 'Scanning...' : 'Scan for Devices'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F7B6C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (_devices.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('ShopLane Devices Found:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C2C2C))),
          const SizedBox(height: 8),
          ..._devices.map((ap) => _deviceTile(ap)),
        ],
      ],
    );
  }

  Widget _deviceTile(WiFiAccessPoint ap) {
    final ssid = ap.ssid ?? 'Unknown';
    final id   = ssid.replaceFirst('ShopLane-', '');
    return GestureDetector(
      onTap: () => _selectDevice(ap),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF0F7B6C).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.developer_board_rounded,
                color: Color(0xFF0F7B6C), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Device ID: $id',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C2C2C))),
                  Text('Signal: ${ap.level} dBm',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFF0F7B6C), size: 16),
          ],
        ),
      ),
    );
  }

  // ── Step 1 UI: PIN entry ───────────────────────────────────
  Widget _buildPinStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Device: ShopLane-$_deviceId',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF2C2C2C))),
        const SizedBox(height: 6),
        Text(
          '1. Go to your phone WiFi settings\n'
          '2. Connect to "ShopLane-$_deviceId"\n'
          '3. Come back here and enter the PIN',
          style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 12),
          decoration: InputDecoration(
            labelText: '4-digit PIN from OLED screen',
            filled: true,
            fillColor: Colors.white,
            counterText: '',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF0F7B6C), width: 2)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _verifyPin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE85A2B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Verify PIN',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ── Step 2 UI: WiFi credentials ───────────────────────────
  Widget _buildWifiStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter the WiFi your shop uses daily.\nThe device will connect to this automatically from now on.',
          style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ssidController,
          decoration: InputDecoration(
            labelText: 'WiFi Name (SSID)',
            prefixIcon: const Icon(Icons.wifi_rounded,
                color: Color(0xFF0F7B6C)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'WiFi Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                color: Color(0xFF0F7B6C)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendCredentials,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F7B6C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Send to Device',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ── Step 3 UI: Success ────────────────────────────────────
  Widget _buildDoneStep() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F7B6C).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF0F7B6C).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF0F7B6C), size: 64),
          const SizedBox(height: 16),
          const Text('Device Configured!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F7B6C))),
          const SizedBox(height: 8),
          const Text(
            'Your ShopLane device will now:\n'
            '• Connect to your WiFi automatically\n'
            '• Beep and show new orders on the screen\n'
            '• Let you accept orders with the button\n\n'
            'To reset: hold the BOOT button while powering on.',
            style: TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF2C2C2C)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F7B6C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }

  // ── How it works section ──────────────────────────────────
  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it works',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF2C2C2C))),
          SizedBox(height: 10),
          _Step(n: '1', text: 'Power on the ShopLane device for the first time'),
          _Step(n: '2', text: 'Tap Scan — your device appears as "ShopLane-XXXX"'),
          _Step(n: '3', text: 'Connect your phone to that WiFi network in settings'),
          _Step(n: '4', text: 'Come back here, enter the PIN shown on the device screen'),
          _Step(n: '5', text: 'Enter your shop WiFi name and password'),
          _Step(n: '6', text: 'Done — device restarts and connects automatically'),
          SizedBox(height: 8),
          Text('To reset: hold the BOOT button while powering on',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFF0F7B6C),
            child: Text(n,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}