import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../role_selection_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'esp32_ble_pairing_screen.dart';
import '../customer/location_picker_screen.dart'; 
import 'esp32_setup_screen.dart';

class VendorSettingsScreen extends StatefulWidget {
  final UserModel vendor;
  final bool embedded;
  const VendorSettingsScreen({super.key, required this.vendor, this.embedded = false});

  @override
  State<VendorSettingsScreen> createState() => _VendorSettingsScreenState();
}

class _VendorSettingsScreenState extends State<VendorSettingsScreen> {
  late bool _isOpen;
  late bool _offersDelivery;
  late bool _offersPickup;
  late double _deliveryFee;
  late double _minOrder;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isOpen = widget.vendor.isOpen ?? false;
    _offersDelivery = widget.vendor.offersDelivery ?? true;
    _offersPickup = widget.vendor.offersPickup ?? true;
    _deliveryFee = widget.vendor.deliveryFee ?? 0;
    _minOrder = widget.vendor.minOrderValue ?? 0;
  }

  Future<void> _updateLocation() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LocationPickerScreen(
        initialLat: widget.vendor.location?.latitude,
        initialLng: widget.vendor.location?.longitude,
      ),
    ),
  );

  if (result == null) return; // vendor backed out of the picker, do nothing

  try {
    final lat = result['lat'] as double;
    final lng = result['lng'] as double;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.vendor.uid)
        .update({'location': GeoPoint(lat, lng)});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location updated successfully'),
        backgroundColor: Color(0xFF0F7B6C),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Location update failed: $e')));
  }
}
  Future<void> _save() async {
    setState(() => _saving = true);
    await FirestoreService().updateVendorSettings(widget.vendor.uid, {
      'isOpen': _isOpen,
      'offersDelivery': _offersDelivery,
      'offersPickup': _offersPickup,
      'deliveryFee': _deliveryFee,
      'minOrderValue': _minOrder,
    });
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved'),
        backgroundColor: Color(0xFF0F7B6C),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _card([
              _switchTile(
                'Shop Open',
                _isOpen,
                (v) => setState(() => _isOpen = v),
              ),
            ]),
            const SizedBox(height: 12),
            _card([
              _switchTile(
                'Offers Delivery',
                _offersDelivery,
                (v) => setState(() => _offersDelivery = v),
              ),
              const Divider(height: 1),
              _switchTile(
                'Offers Pickup',
                _offersPickup,
                (v) => setState(() => _offersPickup = v),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Delivery Fee (₹)'),
                trailing: SizedBox(
                  width: 80,
                  child: TextField(
                    controller: TextEditingController(
                      text: _deliveryFee.toStringAsFixed(0),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(border: InputBorder.none),
                    onChanged: (v) =>
                        _deliveryFee = double.tryParse(v) ?? _deliveryFee,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
  leading: const Icon(Icons.bluetooth_searching),
  title: const Text('Set Up Hardware'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => Esp32SetupScreen(vendorId: widget.vendor.uid),
 )),
),
              ListTile(
                title: const Text('Min Order Value (₹)'),
                trailing: SizedBox(
                  width: 80,
                  child: TextField(
                    controller: TextEditingController(
                      text: _minOrder.toStringAsFixed(0),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(border: InputBorder.none),
                    onChanged: (v) =>
                        _minOrder = double.tryParse(v) ?? _minOrder,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _card([
              ListTile(
                leading: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFF0F7B6C),
                ),
                title: const Text('Update Shop Location'),
                subtitle: const Text(
                  'Customers need this to find you nearby',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: ElevatedButton(
                  onPressed: _updateLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F7B6C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Update', style: TextStyle(fontSize: 13)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _card([
              ListTile(
                leading: const Icon(
                  Icons.developer_board_rounded,
                  color: Color(0xFF0F7B6C),
                ),
                title: const Text('ESP32 Alert Device'),
                subtitle: const Text(
                  'Not paired',
                  style: TextStyle(color: Colors.grey),
                ),
                trailing: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _card([
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFE85A2B)),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Color(0xFFE85A2B)),
                ),
                onTap: () async {
                  await AuthService().logout();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
            ]),
          ],
        ),
      );

    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF2F1EF),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: const Color(0xFF0F7B6C),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: _saving ? null : _save,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Color(0xFF2C2C2C),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFF0F7B6C),
    );
  }
}