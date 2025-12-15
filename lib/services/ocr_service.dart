import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OcrService {
  // مفتاح API الخاص بك
  final String _apiKey = dotenv.env['GOOGLE_GEMINI_API_KEY'] ?? '';
  
  // لتتبع وقت آخر طلب (لتجنب تجاوز الحد المجاني)
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(seconds: 30);

  /// التحقق من الوقت المتبقي قبل السماح بطلب جديد
  static Duration getRemainingCooldown() {
    if (_lastRequestTime == null) return Duration.zero;
    final timeSinceLast = DateTime.now().difference(_lastRequestTime!);
    if (timeSinceLast < _minRequestInterval) {
      return _minRequestInterval - timeSinceLast;
    }
    return Duration.zero;
  }

  Future<String?> extractTextFromImage(File imageFile) async {
    try {
      // تحديث وقت الطلب عند البدء الفعلي
      _lastRequestTime = DateTime.now(); 

      print("🚀 Processing image with Gemma 3 27B IT...");

      // 1. ضغط الصورة لتسريع الإرسال
      var resultBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      final bytes = resultBytes ?? await imageFile.readAsBytes();
      final String base64Image = base64Encode(bytes);

      // 2. تجهيز الطلب (Gemma 3 27B IT)
      // استخدام نموذج Gemma المفتوح مع خدعة الـ Prompt للحصول على JSON
      final Uri uri = Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/gemma-3-27b-it:generateContent?key=$_apiKey");

      final Map<String, dynamic> requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": """
Role: You are a strict API backend machine. You connect directly to a compiler.
Task: Analyze the provided image (medical prescription or invoice) and extract medicine data.
Constraint 1: Output MUST be a valid raw JSON list of objects. Each object MUST have exactly these keys: "medicine_name", "package", "price".
Constraint 2: Do NOT write "Here is the json". Do NOT use markdown blocks like ```json.
Constraint 3: Start your response immediately with [.
Constraint 4: If price is missing, use 0. Correct spelling of English medicine names.

Input Image Attached.
"""
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.1, // حرارة منخفضة جداً للالتزام بالتعليمات
          "maxOutputTokens": 2048,
          // تم إزالة response_mime_type لأن Gemma لا يدعمه
        }
      };

      // 3. إرسال الطلب
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final candidates = jsonResponse['candidates'] as List;
        if (candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List;
          if (parts.isNotEmpty) {
            String text = parts[0]['text'];
            
            // تنظيف إضافي احتياطي (في حال خالف النموذج التعليمات ووضع markdown)
            text = text.replaceAll('```json', '').replaceAll('```', '').trim();
            
            print("✅ Gemma-3-27b Result:");
            print(text);

            return text;
          }
        }
      } else {
        print("❌ Gemini/Gemma API Error: ${response.statusCode} - ${response.body}");
        if (response.statusCode == 429) {
           return "تجاوزت الحد المسموح (429).";
        }
        if (response.statusCode == 404) {
           return "النموذج غير موجود (404). قد لا يكون Gemma-3 متاحاً في الـ API العام بعد.";
        }
        return "حدث خطأ في الخدمة: ${response.statusCode}";
      }
    } catch (e) {
      print("❌ Exception: $e");
      return null;
    }
    return null;
  }
}
