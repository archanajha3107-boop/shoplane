// gemini_mrp_service.dart
// Advisory-only MRP suggestion — NEVER auto-fills or blocks anything.
// The vendor always sees this labeled clearly as an unverified AI estimate,
// never as fact, per the real limitation: LLMs can confidently state a
// wrong price since they have no live connection to current Indian retail data.

import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiMrpService {
  // Paste your free API key from aistudio.google.com here.
  // Free Groq API key – replace with your own key from https://groq.com
  static const String _apiKey = 'YOUR_GROQ_API_KEY';
  // Using Groq's free Llama3 model for MRP suggestions
  static const String _model = 'llama3-8b-8192';

  // Returns a suggested MRP in rupees, or null if Gemini has no reliable
  // knowledge of the product (explicitly asked to say so rather than guess).
  static Future<double?> suggestMrp(String productName) async {
    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final prompt = '''
What is a typical MRP in Indian Rupees for this retail product: "$productName"? This is for a rough vendor pricing sanity-check, not for legal/financial use. If you have reasonable confidence, reply with ONLY a number (no currency symbol, no text, no range) — e.g. "45". check the quantity of product as well for correct pricing value If you are not confident about this specific product, reply with EXACTLY the word: UNKNOWN. Do not guess if unsure.
''' ;

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.1,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null; // fail silently — this is advisory only, never block the vendor's flow
      }

      final data = jsonDecode(response.body);
      final text = data['choices']?[0]?['message']?['content'] as String?;

      if (text == null) return null;
      final cleaned = text.trim();

      if (cleaned.toUpperCase().contains('UNKNOWN')) return null;

      // Extract just the first number found, in case Gemini adds stray text
      // despite instructions — real models don't always follow format perfectly.
      final match = RegExp(r'\d+(\.\d+)?').firstMatch(cleaned);
      if (match == null) return null;

      return double.tryParse(match.group(0)!);
    } catch (e) {
      return null; // network error, timeout, parse failure — all fail silently, never crash the add-product flow
    }
  }
}