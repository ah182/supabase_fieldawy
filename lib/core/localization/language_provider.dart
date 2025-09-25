import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

// 1. Provider الذي ستحتفظ فيه باللغة الحالية
final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  return LanguageNotifier();
});

// 2. المتحكم الذي يدير منطق تغيير وحفظ اللغة
// في ملف language_provider.dart

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier() : super(const Locale('ar')) {
    _loadLocale();
  }

  void _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('languageCode') ?? 'ar';
    state = Locale(languageCode);
  }

  Future<void> setLocale(Locale locale) async {
    if (state == locale) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
    state = locale;
  }
}
