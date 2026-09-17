import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../services/firestore_service.dart';
import '../../models/product_model.dart';

class VoiceProductScreen extends StatefulWidget {
  final String vendorId;
  final bool embedded;

  const VoiceProductScreen({
    super.key,
    required this.vendorId,
    this.embedded = false,
  });

  @override
  State<VoiceProductScreen> createState() => _VoiceProductScreenState();
}

class _VoiceProductScreenState extends State<VoiceProductScreen>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  late final AnimationController _pulseController;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _spokenText = '';
  String? _parsedName;
  double? _parsedPrice;
  String? _parsedUnit; // NEW — e.g. "kg", "litre", "piece"
  String _parsedCategory = 'Groceries';

  final List<String> _categories = [
    'Groceries',
    'Vegetables',
    'Fruits',
    'Dairy',
    'Meat & Fish',
    'Snacks',
  ];

  // Recognized units — covers the common ways people actually say these
  static const Map<String, String> _unitAliases = {
    'kg': 'kg', 'kilo': 'kg', 'kilogram': 'kg', 'kilograms': 'kg',
    'gram': 'g', 'grams': 'g', 'gm': 'g', 'g': 'g',
    'litre': 'L', 'liter': 'L', 'litres': 'L', 'liters': 'L', 'l': 'L',
    'ml': 'ml', 'millilitre': 'ml', 'milliliter': 'ml',
    'dozen': 'dozen',
    'piece': 'piece', 'pieces': 'piece', 'pc': 'piece', 'pcs': 'piece',
    'packet': 'packet', 'pack': 'packet',
  };

  String get _recognizedText => _spokenText;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.8,
      upperBound: 1.4,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _pulseController.forward();
      }
    });
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) => debugPrint('SPEECH ERROR: ${error.errorMsg}'),
      onStatus: (status) => debugPrint('SPEECH STATUS: $status'),
    );
    debugPrint('SPEECH AVAILABLE: $_speechAvailable');
    setState(() {});
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    setState(() {
      _isListening = true;
      _spokenText = '';
      _parsedName = null;
      _parsedPrice = null;
      _parsedUnit = null;
    });

    _pulseController.forward();
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _spokenText = result.recognizedWords;
        });
        if (result.finalResult) {
          _parseSpokenText(_spokenText);
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 10),
        localeId: 'en_IN',
      ),
    );
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    setState(() => _isListening = false);
    _pulseController.stop();
    await _speech.stop();
  }

  Future<void> _listen() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  void _parseSpokenText(String text) {
    text = text.toLowerCase().trim();

    final priceMatch = RegExp(r'\d+').allMatches(text);
    double? price;
    String? productName;
    String? unit;

    if (priceMatch.isNotEmpty) {
      final match = priceMatch.first;
      price = double.tryParse(match.group(0)!);

      // Name = everything BEFORE the number, same as before
      final firstDigit = text.indexOf(RegExp(r'\d'));
      if (firstDigit > 0) {
        productName = text
            .substring(0, firstDigit)
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .trim();
        if (productName.isNotEmpty) {
          productName = productName[0].toUpperCase() + productName.substring(1);
        }
      }

      // NEW: look for a unit word in whatever comes AFTER the number
      // e.g. "tomatoes 40 rupees per kg" -> catches "kg"
      // e.g. "milk 60 a litre" -> catches "litre" -> normalized to "L"
      final afterNumber = text.substring(match.end).trim();
      final words = afterNumber.split(RegExp(r'\s+'));
      for (final word in words) {
        final cleaned = word.replaceAll(RegExp(r'[^\w]'), '');
        if (_unitAliases.containsKey(cleaned)) {
          unit = _unitAliases[cleaned];
          break;
        }
      }
    }

    String category = 'Groceries';
    if (text.contains('tomato') || text.contains('potato') || text.contains('onion') ||
        text.contains('carrot') || text.contains('vegetable')) {
      category = 'Vegetables';
    } else if (text.contains('apple') || text.contains('banana') ||
        text.contains('mango') || text.contains('fruit')) {
      category = 'Fruits';
    } else if (text.contains('milk') || text.contains('curd') ||
        text.contains('paneer') || text.contains('dairy')) {
      category = 'Dairy';
    } else if (text.contains('chicken') || text.contains('fish') ||
        text.contains('mutton') || text.contains('meat')) {
      category = 'Meat & Fish';
    } else if (text.contains('biscuit') || text.contains('chips') ||
        text.contains('snack') || text.contains('sandwich') ||
        text.contains('sandwhich') || text.contains('burger') || text.contains('roll')) {
      category = 'Snacks';
    }

    setState(() {
      _parsedName = productName;
      _parsedPrice = price;
      _parsedUnit = unit; // may be null if nothing recognized — vendor confirms/edits in dialog
      _parsedCategory = category;
    });

    // Instead of saving straight away, open the same-style confirmation
    // dialog the manual flows use — vendor can fix the parse, set a unit,
    // pick a category, and add a photo before anything is written.
    if (productName != null && price != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openConfirmDialog());
    }
  }

  void _openConfirmDialog() {
    final nameController = TextEditingController(text: _parsedName ?? '');
    final priceController = TextEditingController(text: _parsedPrice?.toStringAsFixed(0) ?? '');
    final unitController = TextEditingController(text: _parsedUnit ?? '');
    String selectedCategory = _categories.contains(_parsedCategory) ? _parsedCategory : _categories.first;
    File? pickedImageFile;
    String? pickedEmoji;
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Confirm Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Heard: "$_spokenText"', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 12),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Product Name')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(prefixText: '₹', labelText: 'Price'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: unitController,
                        decoration: const InputDecoration(labelText: 'Unit', hintText: 'kg, L...'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v ?? selectedCategory),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                const Text('Product Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (pickedImageFile != null)
                  ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: Image.file(pickedImageFile!, height: 90, width: 90, fit: BoxFit.cover))
                else if (pickedEmoji != null)
                  Container(height: 90, width: 90, alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Text(pickedEmoji!, style: const TextStyle(fontSize: 44)))
                else
                  Container(height: 90, width: 90, alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () async {
                        final file = await _pickImage(ImageSource.camera);
                        if (file != null) setDialogState(() { pickedImageFile = file; pickedEmoji = null; });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library),
                      onPressed: () async {
                        final file = await _pickImage(ImageSource.gallery);
                        if (file != null) setDialogState(() { pickedImageFile = file; pickedEmoji = null; });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined),
                      onPressed: () async {
                        final emoji = await _showEmojiPicker(dialogContext);
                        if (emoji != null) setDialogState(() { pickedEmoji = emoji; pickedImageFile = null; });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text);
                final unit = unitController.text.trim();

                if (name.isEmpty) { setDialogState(() => errorText = 'Enter a product name'); return; }
                if (price == null || price <= 0) { setDialogState(() => errorText = 'Enter a valid price'); return; }

                String? imageBase64;
                if (pickedImageFile != null) {
                  imageBase64 = base64Encode(await pickedImageFile!.readAsBytes());
                }

                await _saveProduct(
                  name: name,
                  price: price,
                  unit: unit.isNotEmpty ? unit : null,
                  category: selectedCategory,
                  imageBase64: imageBase64,
                  emoji: pickedEmoji,
                );

                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<File?> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 40, maxWidth: 600);
    if (picked == null) return null;
    return File(picked.path);
  }

  Future<String?> _showEmojiPicker(BuildContext context) {
    const emojis = ['🥦','🍅','🥔','🍌','🍎','🥬','🥕','🍚','🌾','🫘','🧂','🛢️','🥛','🍶','🧀','🧈','🍗','🐐','🐟','🥚','🍪','🍟','🍫','🛒'];
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => GridView.count(
        crossAxisCount: 6,
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        children: emojis.map((e) => IconButton(
          icon: Text(e, style: const TextStyle(fontSize: 28)),
          onPressed: () => Navigator.pop(sheetContext, e),
        )).toList(),
      ),
    );
  }

  Future<void> _saveProduct({
    required String name,
    required double price,
    String? unit,
    required String category,
    String? imageBase64,
    String? emoji,
  }) async {
    try {
      final product = ProductModel(
        id: '',
        sellerId: widget.vendorId,
        name: unit != null ? '$name ($unit)' : name, // e.g. "Tomatoes (kg)" — keeps unit visible in the name itself since ProductModel has no separate unit field
        price: price,
        category: category,
        inStock: true,
        isVariableStock: category == 'Meat & Fish',
        lastUpdated: DateTime.now(),
      );
      await FirestoreService().addProduct(product);

      // Extra fields (image/emoji) added on top via a follow-up query,
      // since FirestoreService.addProduct() only writes the base ProductModel schema.
      // We just created this document, so querying by sellerId + name + most
      // recent lastUpdated reliably finds it back.
      if (imageBase64 != null || emoji != null) {
        final match = await FirebaseFirestore.instance
            .collection('products')
            .where('sellerId', isEqualTo: widget.vendorId)
            .where('name', isEqualTo: product.name)
            .orderBy('lastUpdated', descending: true)
            .limit(1)
            .get();
        if (match.docs.isNotEmpty) {
          await match.docs.first.reference.update({
            if (imageBase64 != null) 'imageBase64': imageBase64,
            if (emoji != null) 'emoji': emoji,
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added to catalog!'), backgroundColor: const Color(0xFF0F7B6C)),
      );
      setState(() {
        _spokenText = '';
        _parsedName = null;
        _parsedPrice = null;
        _parsedUnit = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: const Column(
                  children: [
                    Text('Say something like:', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('"Tomatoes 40 rupees per kg"'),
                    Text('"Milk 60 a litre"'),
                    Text('"Chicken 200 rupees per kg"'),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: _isListening ? Colors.orange : Colors.teal,
                  child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 12),
              Text(_isListening ? 'Listening...' : 'Tap to speak',
                  style: TextStyle(color: _isListening ? Colors.orange : Colors.grey)),
              const SizedBox(height: 20),
              if (_recognizedText.isNotEmpty) ...[
                Text('Heard: $_recognizedText'),
                const SizedBox(height: 8),
                Text('Parsed: $_parsedName — ₹$_parsedPrice${_parsedUnit != null ? " / $_parsedUnit" : ""} — $_parsedCategory'),
                const SizedBox(height: 8),
                const Text('Confirm details in the popup to save.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: const Color(0xFF0F7B6C),
                child: const Text('Voice Add Product',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Expanded(child: body),
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
        title: const Text('Voice Add Product'),
      ),
      body: body,
    );
  }
}