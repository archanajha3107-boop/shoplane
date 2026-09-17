
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import 'smart_split_screen.dart';
import '../../services/vendor_matcher.dart';

class BuildShoppingListScreen extends StatefulWidget {
  final UserModel customer;
  const BuildShoppingListScreen({super.key, required this.customer});

  @override
  State<BuildShoppingListScreen> createState() => _BuildShoppingListScreenState();
}

class _BuildShoppingListScreenState extends State<BuildShoppingListScreen> {
  final List<String> _list = [];
  final _controller = TextEditingController();
  bool _loading = false;

  void _addItem() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _list.add(text);
      _controller.clear();
    });
  }

  Future<void> _findVendors() async {
  setState(() => _loading = true);
  final firestoreService = FirestoreService();
  final nearbyVendors = await firestoreService.getNearbyVendors(
    customerLat: widget.customer.location?.latitude,
    customerLng: widget.customer.location?.longitude,
  );
  final result = await findVendorsForList(_list, nearbyVendors);
  setState(() => _loading = false);
  if (mounted) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SmartSplitScreen(result: result, customer: widget.customer),
    ));
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('What do you need today?'), backgroundColor: const Color(0xFF0F7B6C)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'e.g. tomatoes',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _addItem),
              ),
              onSubmitted: (_) => _addItem(),
            ),
          ),
          Expanded(
            child: _list.isEmpty
                ? const Center(child: Text('Add a few items to get started', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _list.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(_list[i]),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _list.removeAt(i)),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _list.isEmpty || _loading ? null : _findVendors,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE85A2B), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Find Shops for This List', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}