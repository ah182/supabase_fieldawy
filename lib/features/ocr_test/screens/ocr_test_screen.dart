import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../services/ai_analysis_service.dart';
import '../models/medicine_data.dart';

class OcrTestScreen extends StatefulWidget {
  const OcrTestScreen({super.key});

  @override
  State<OcrTestScreen> createState() => _OcrTestScreenState();
}

class _OcrTestScreenState extends State<OcrTestScreen> {
  final OcrService _ocrService = OcrService();
  final AiAnalysisService _aiService = AiAnalysisService();
  final TextEditingController _apiKeyController = TextEditingController(
    text: "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"
  );

  File? _selectedImage;
  // ignore: unused_field
  String? _extractedText;
  MedicineData? _medicineData;
  bool _isProcessing = false;
  String _statusMessage = "";

  // Step 1: Pick Image
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _extractedText = null;
        _medicineData = null;
        _statusMessage = "Image selected. Ready to process.";
      });
    }
  }

  // Step 2 & 3: Process (OCR + AI)
  Future<void> _processImage() async {
    if (_selectedImage == null) return;
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an OpenRouter API Key')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Extracting text using ML Kit (Local)...";
    });

    try {
      // 1. Local OCR (Fast & Reliable)
      final ocrText = await _ocrService.processImage(XFile(_selectedImage!.path));
      
      setState(() {
        _extractedText = ocrText;
        _statusMessage = "Text extracted. Analyzing with AI...";
      });

      if (ocrText.trim().isEmpty) {
         throw Exception("No text found in image. Please try a clearer photo.");
      }

      // 2. AI Analysis based on extracted text
      final result = await _aiService.analyzeText(ocrText, _apiKeyController.text.trim());

      setState(() {
        _medicineData = result;
        _statusMessage = "Analysis Complete!";
      });

    } catch (e) {
      setState(() {
        _statusMessage = "Error: $e";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OCR & AI Medicine Scanner"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API Key Input
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: "OpenRouter API Key (Free Model)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
                helperText: "Get a key from openrouter.ai (supports free models)",
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),

            // Image Area
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[100],
              ),
              child: _selectedImage == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image, size: 50, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text("No Image Selected", style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_selectedImage!, fit: BoxFit.contain),
                    ),
            ),
            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Gallery"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Camera"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: (_selectedImage != null && !_isProcessing) ? _processImage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isProcessing 
                ? const SizedBox(
                    height: 20, 
                    width: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                : const Text("PROCESS IMAGE (OCR + AI)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),

            const SizedBox(height: 20),
            
            // Status
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _statusMessage.startsWith("Error") ? Colors.red : Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 30),

            // Results Section
            if (_medicineData != null) ...[
              const Text("AI Analysis Result:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildResultCard("Medicine Name", _medicineData!.name, Icons.medication),
              _buildResultCard("Active Ingredient", _medicineData!.activeIngredient, Icons.science),
              _buildResultCard("Company", _medicineData!.company, Icons.business),
              _buildResultCard("Package Size", _medicineData!.packageSize, Icons.inventory_2),
            ],

            // Raw Text section removed as requested to focus on final cleaned output
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(String label, String? value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.withOpacity(0.1),
          child: Icon(icon, color: Colors.teal),
        ),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(
          value ?? "Not Detected", 
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
            color: value == null ? Colors.red : Colors.black87
          )
        ),
      ),
    );
  }
}
