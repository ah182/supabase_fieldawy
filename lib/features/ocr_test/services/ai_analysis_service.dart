import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/medicine_data.dart';

class AiAnalysisService {
  // Using the stable text-based free model
  static const String _model = "google/gemma-3-27b-it:free";
  static const String _apiUrl = "https://openrouter.ai/api/v1/chat/completions";

  Future<MedicineData> analyzeText(String ocrText, String apiKey) async {
    if (apiKey.isEmpty) {
      throw Exception('API Key is missing');
    }

    final prompt = '''
    You are an expert Pharmacist and OCR Data Cleaner.
    The following text is extracted from a medicine package and contains OCR errors, noise, and typos.
    
    YOUR TASKS:
    1. **CORRECT** any spelling errors in medicine names or active ingredients (e.g., treat "Pnadol" as "Panadol", "Amoxcil" as "Amoxicillin").
    2. **IGNORE** gibberish, random symbols, batch numbers, or manufacturing dates.
    3. **EXTRACT** the corrected details into a clean JSON object.

    REQUIRED FIELDS:
    1. "name": The corrected commercial name.
    2. "active_ingredient": The scientific name. If missing or misspelled, INFER it from the brand name.
    3. "company": The manufacturer name (correct spelling if needed).
    4. "package_size": The volume/count (e.g., "100ml", "30 Tablets").

    OCR TEXT:
    """
    $ocrText
    """
    
    Return ONLY the JSON object. No markdown.
    ''';

    print("🤖 [AI DEBUG] Preparing to send request to $_model");
    
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": _model,
          "messages": [
            {
              "role": "user",
              "content": prompt,
            }
          ],
        }),
      );

      print("📥 [AI DEBUG] Response Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        print("🧹 [AI DEBUG] Raw Content: '$content'");

        String cleanJson = content.trim();
        final int startIndex = cleanJson.indexOf('{');
        final int endIndex = cleanJson.lastIndexOf('}');

        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          cleanJson = cleanJson.substring(startIndex, endIndex + 1);
        }

        print("✨ [AI DEBUG] Cleaned JSON: '$cleanJson'");

        return MedicineData.fromJson(jsonDecode(cleanJson));
      } else {
        throw Exception("API Error: ${response.body}");
      }
    } catch (e) {
      rethrow;
    }
  }
}