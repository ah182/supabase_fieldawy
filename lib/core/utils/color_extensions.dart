import 'package:flutter/material.dart';

/// Extension لإصلاح مشكلة withOpacity المتوقفة
/// Extension to fix deprecated withOpacity issue
extension ColorExtensions on Color {
  /// بديل لـ withOpacity المتوقفة
  /// Alternative to deprecated withOpacity
  Color withOpacityFixed(double opacity) {
    return withValues(alpha: opacity);
  }
  
  /// دالة سريعة للشفافية الشائعة
  /// Quick function for common opacity values
  Color get semi => withValues(alpha: 0.5);
  Color get light => withValues(alpha: 0.1);
  Color get medium => withValues(alpha: 0.3);
  Color get strong => withValues(alpha: 0.7);
  Color get veryLight => withValues(alpha: 0.05);
}