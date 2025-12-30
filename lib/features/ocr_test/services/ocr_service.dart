import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OcrService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> processImage(XFile imageFile) async {
    print("📸 [OCR DEBUG] Starting processing for image: ${imageFile.path}");
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    
    print("📝 [OCR DEBUG] Extracted Text Raw Start --------------------------------");
    print(recognizedText.text);
    print("📝 [OCR DEBUG] Extracted Text Raw End ----------------------------------");
    
    return recognizedText.text;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
