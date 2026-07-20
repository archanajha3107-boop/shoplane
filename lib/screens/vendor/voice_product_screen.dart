import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../services/firestore_service.dart';
import '../../models/product_model.dart';

class VoiceProductScreen extends StatefulWidget {
  final String vendorId;
  const VoiceProductScreen({super.key, required this.vendorId});

  @override
  State<VoiceProductScreen> createState() => _VoiceProductScreenState();
}

class _VoiceProductScreenState extends State<VoiceProductScreen> {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _spokenText = '';
  String? _parsedName;
  double? _parsedPrice;
  String _parsedCategory = 'Groceries';
  bool _saving = false;

  final List<String> _categories = [
    'Groceries', 'Vegetables', 'Fruits',
    'Dairy', 'Meat & Fish', 'Snacks'
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    setState(() {});
  }

  Future<void> _listen() async {
    if (!_isListening) {
      setState(() {
        _isListening = true;
        _spokenText = '';
        _parsedName = null;
        _parsedPrice = null;
      });
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _spokenText = result.recognizedWords;
          });
          if (result.finalResult) {
            _parseSpokenText(_spokenText);
          }
        },
        listenFor: const Duration(seconds: 10),
        localeId: 'en_IN',
      );
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
    }
  }

  void _parseSpokenText(String text) {
    // Parse "tomatoes 40 rupees" or "milk 60" or "chicken 200 rupees per kg"
    text = text.toLowerCase().trim();

    // Extract price — look for numbers
    final priceMatch = RegExp(r'\d+').allMatches(text);
    double? price;
    String? productName;

    if (priceMatch.isNotEmpty) {
      price = double.tryParse(priceMatch.first.group(0)!);
      // Product name is everything before the first number
      final firstDigit = text.indexOf(RegExp(r'\d'));
      if (firstDigit > 0) {
        productName = text
            .substring(0, firstDigit)
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .trim();
        // Capitalize first letter
        if (productName.isNotEmpty) {
          productName =
              productName[0].toUpperCase() + productName.substring(1);
        }
      }
    }

    // Guess category from keywords
    String category = 'Groceries';
    if (text.contains('tomato') || text.contains('potato') ||
        text.contains('onion') || text.contains('carrot') ||
        text.contains('vegetable')) {
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
        text.contains('snack')) {
      category = 'Snacks';
    }

    setState(() {
      _parsedName = productName;
      _parsedPrice = price;
      _parsedCategory = category;
    });
  }

  Future<void> _saveProduct() async {
    if (_parsedName == null || _parsedPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Could not parse product. Try again.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final product = ProductModel(
        id: '',
        sellerId: widget.vendorId,
        name: _parsedName!,
        price: _parsedPrice!,
        category: _parsedCategory,
        inStock: true,
        isVariableStock: _parsedCategory == 'Meat & Fish',
        lastUpdated: DateTime.now(),
      );
      await FirestoreService().addProduct(product);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_parsedName!} added to catalog!'),
          backgroundColor: const Color(0xFF0F7B6C),
        ),
      );
      // Reset for next product
      setState(() {
        _spokenText = '';
        _parsedName = null;
        _parsedPrice = null;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7B6C),
        foregroundColor: Colors.white,
        title: const Text('Voice Add Product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F7B6C).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Text('Say something like:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F7B6C))),
                  SizedBox(height: 8),
                  Text('"Tomatoes 40 rupees"',
                      style: TextStyle(color: Color(0xFF2C2C2C))),
                  Text('"Milk 60"',
                      style: TextStyle(color: Color(0xFF2C2C2C))),
                  Text('"Chicken 200 rupees"',
                      style: TextStyle(color: Color(0xFF2C2C2C))),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Mic button
            GestureDetector(
              onTap: _speechAvailable ? _listen : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isListening ? 100 : 80,
                height: _isListening ? 100 : 80,
                decoration: BoxDecoration(
                  color: _isListening
                      ? const Color(0xFFE85A2B)
                      : const Color(0xFF0F7B6C),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening
                              ? const Color(0xFFE85A2B)
                              : const Color(0xFF0F7B6C))
                          .withValues(alpha: 0.4),
                      blurRadius: _isListening ? 20 : 10,
                      spreadRadius: _isListening ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isListening
                  ? 'Listening...'
                  : 'Tap to speak',
              style: TextStyle(
                color: _isListening
                    ? const Color(0xFFE85A2B)
                    : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            // Spoken text display
            if (_spokenText.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '"$_spokenText"',
                  style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2C2C2C),
                      fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            // Parsed result
            if (_parsedName != null || _parsedPrice != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF0F7B6C), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Parsed:',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Product: ',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 14)),
                        Text(
                          _parsedName ?? 'Could not detect',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C2C2C),
                              fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Price: ',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 14)),
                        Text(
                          _parsedPrice != null
                              ? '₹${_parsedPrice!.toStringAsFixed(0)}'
                              : 'Could not detect',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F7B6C),
                              fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Category: ',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 14)),
                        DropdownButton<String>(
                          value: _parsedCategory,
                          underline: const SizedBox(),
                          style: const TextStyle(
                              color: Color(0xFF2C2C2C),
                              fontWeight: FontWeight.w600),
                          items: _categories
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _parsedCategory = v!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              _spokenText = '';
                              _parsedName = null;
                              _parsedPrice = null;
                            }),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  const Color(0xFFE85A2B),
                              side: const BorderSide(
                                  color: Color(0xFFE85A2B)),
                            ),
                            child: const Text('Try Again'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveProduct,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF0F7B6C),
                              foregroundColor: Colors.white,
                            ),
                            child: _saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2))
                                : const Text('Add Product'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}