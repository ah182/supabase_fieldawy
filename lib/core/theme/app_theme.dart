import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // إضافة استيراد لدعم unawaited

// --- Provider جديد للتحكم في حالة الثيم ---
final themeNotifierProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    // تحميل الثيم بشكل غير متزامن دون إيقاف واجهة المستخدم
    _loadTheme();
  }

  // دالة لتحميل الثيم المحفوظ - محسنة
  void _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt('themeMode') ?? 2; // 0=light, 1=dark, 2=system
      // تحديث الحالة فقط إذا كانت مختلفة عن الحالة الافتراضية
      if (state != ThemeMode.values[themeIndex]) {
        state = ThemeMode.values[themeIndex];
      }
    } catch (e) {
      // في حالة حدوث خطأ، نستخدم الثيم الافتراضي
      state = ThemeMode.system;
    }
  }

  // دالة لتغيير الثيم وحفظ الاختيار - محسنة
  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;

    // تحديث الحالة فوراً لتحسين الاستجابة
    state = mode;

    // حفظ الاختيار في الخلفية دون إعاقة واجهة المستخدم
    unawaited(_saveThemePreference(mode));
  }

  // دالة مساعدة لحفظ تفضيلات الثيم في الخلفية
  Future<void> _saveThemePreference(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('themeMode', mode.index);
    } catch (e) {
      // يمكن إضافة تسجيل للأخطاء هنا إذا لزم الأمر
      debugPrint('Error saving theme preference: $e');
    }
  }
}

// هذا الكلاس يبقى كما هو
class AppTheme {
  AppTheme._();

// === ألوان البالتة (نفس اللي في الثيم الداكن) ===
  static const Color kTeal = Color(0xFF52D3D8); // أكسنت هادي
  static const Color kBlue = Color(0xFF3887BE); // أزرق أساسي
  static const Color kIndigo = Color(0xFF38419D); // بنفسجي/إنديغو
  static const Color kNavy = Color(
      0xFF200E3A); // خلفية داكنة جداً (مش هنستخدمه كخلفية في الـ light theme)

// === الثيم النهاري (Light Theme) ===
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    brightness: Brightness.light, // تحديد الوضع الفاتح

    // === ColorScheme باستخدام البالتة ===
    colorScheme: ColorScheme.fromSeed(
      seedColor: kBlue, // استخدام kBlue كلون أساسي للحساب
      brightness: Brightness.light,
    ).copyWith(
      // --- الألوان الرئيسية (Primary) - باستخدام kTeal كأكسنت ---
      primary: kTeal, // اللون الأساسي (الأزرق الفاتح الهادي)
      onPrimary: Colors.white, // لون النص على الأولي (أبيض علشان يبان عليه)
      primaryContainer:
          kTeal.withAlpha(26), // حاوية أولية أفتح (علشان البطاقات المميزة)
      onPrimaryContainer: kNavy, // لون النص على حاوية الأولي ( Navy داكن)

      // --- الألوان الثانوية (Secondary) - باستخدام kBlue ---
      secondary: kBlue, // اللون الثانوي (الأزرق الأساسي)
      onSecondary: Colors.white, // لون النص على الثانوي
      secondaryContainer: kBlue.withAlpha(26), // حاوية ثانوية أفتح
      onSecondaryContainer: kNavy, // لون النص على حاوية الثانوي

      // --- الألوان الثالثية (Tertiary) - باستخدام kIndigo ---
      tertiary: kIndigo, // اللون الثالثي (البنفسجي)
      onTertiary: Colors.white, // لون النص على الثالثي
      tertiaryContainer: kIndigo.withAlpha(26), // حاوية ثالثية أفتح
      onTertiaryContainer: kNavy, // لون النص على حاوية الثالثي

      // --- ألوان الخلفيات والأسطح ---
      surface: Colors.white, // أسطح البطاقات والمكونات (أبيض)
      onSurface: kNavy, // نص على الأسطح ( Navy داكن)
      surfaceContainerHighest:
          const Color(0xFFe2e4eb), // سطح متنوع ( чуть أفتح من surface)
      onSurfaceVariant: kNavy.withAlpha(179), // نص على السطح المتنوع

      // --- ألوان أخرى ---
      outline: const Color(0xFFd1d3da), // حدود خفيفة (رمادية فاتحة)
      outlineVariant:
          const Color(0xFFe1e3ea), // حدود متنوعة ( чуть أغمق من outline)
      shadow: Colors.black.withAlpha(26), // لون الظل (أسود شفاف)
      scrim: Colors.black, // لون scrim (overlay)
      inverseSurface: kNavy, // سطح معكوس (علشان الوضع الداكن)
      onInverseSurface: Colors.white, // نص على السطح المعكوس
      inversePrimary: kNavy, // أولي معكوس
      error: const Color(0xFFB00020), // لون الخطأ (أحمر فاتح Material)
      onError: Colors.white, // نص على الخطأ
      errorContainer: const Color(0xFFB00020).withAlpha(26), // حاوية خطأ
      onErrorContainer: const Color(0xFFB00020), // نص على حاوية الخطأ
    ),

    // === خلفية الشاشة ===
    scaffoldBackgroundColor:
        const Color(0xFFf3f4f7), // نفس خلفية الـ background

    // === AppBar ===
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 2,
      backgroundColor: Colors.white, // خلفية بيضاء
      foregroundColor: kNavy, // لون الأيقونات والنص ( Navy داكن)
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: kNavy,
      ),
      iconTheme: IconThemeData(color: kNavy),
      actionsIconTheme: IconThemeData(color: kNavy),
    ),

    // === Card ===
    cardTheme: CardThemeData(
      elevation: 1,
      color: Colors.white, // خلفية بيضاء
      shadowColor: Colors.black.withAlpha(13), // ظل أخف
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: const Color(0xFFd1d3da).withAlpha(128), // حد أخف للبطاقة
          width: 0.5,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    // === ElevatedButton ===
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kTeal, // لون الزرار (الأكسنت)
        foregroundColor: Colors.white, // لون النص (أبيض)
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBackgroundColor: kTeal.withAlpha(128),
        disabledForegroundColor: Colors.white.withAlpha(128),
      ),
    ),

    // === OutlinedButton ===
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kTeal, // لون النص والحد (الأكسنت)
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(
          color: kTeal.withAlpha(179), // لون الحد
          width: 1.5,
        ),
        disabledForegroundColor: kTeal.withAlpha(128),
      ),
    ),

    // === TextButton ===
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kTeal, // لون النص (الأكسنت)
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
        ),
        disabledForegroundColor: kTeal.withAlpha(128),
      ),
    ),

    // === InputDecoration (TextFields, etc.) ===
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor:
          const Color(0xFFf8f9fc), // خلفية الحقل ( чуть أفتح من background)
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFFd1d3da).withAlpha(179), // حد عادي
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFFd1d3da).withAlpha(179), // حد مفعل
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: kTeal, // حد مختار (الأكسنت)
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFB00020), // حد خطأ
          width: 2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFB00020), // حد خطأ مختار
          width: 2,
        ),
      ),
      labelStyle: TextStyle(color: kNavy.withAlpha(179)),
      floatingLabelStyle: TextStyle(color: kTeal, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: kNavy.withAlpha(128)),
      prefixIconColor: kNavy.withAlpha(153),
      suffixIconColor: kNavy.withAlpha(153),
    ),

    // === Switch ===
    switchTheme: SwitchThemeData(
      thumbColor:
          WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return kTeal; // لون الزرّاعة لما يكون مفعل (الأكسنت)
        }
        return Colors.white; // لون الزرّاعة لما يكون مش مفعل
      }),
      trackColor:
          WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return kTeal
              .withAlpha(128); // لون الخلفية لما يكون مفعل (الأكسنت شفاف)
        }
        return const Color(0xFFd1d3da)
            .withAlpha(128); // لون الخلفية لما يكون مش مفعل
      }),
    ),

    // === SnackBar ===
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFFe2e4eb), // خلفية الـ SnackBar
      contentTextStyle: const TextStyle(fontFamily: 'Cairo', color: kNavy),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 4,
    ),

    // === Divider ===
    dividerTheme: const DividerThemeData(
      color: Color(0xFFd1d3da), // لون الـ Divider
      thickness: 1,
      space: 1,
    ),

    // === TextTheme ===
    textTheme: TextTheme(
      displayLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 57,
          fontWeight: FontWeight.bold,
          color: kNavy),
      displayMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 45,
          fontWeight: FontWeight.bold,
          color: kNavy),
      displaySmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: kNavy),
      headlineLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: kNavy),
      headlineMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: kNavy),
      headlineSmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: kNavy),
      titleLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: kNavy),
      titleMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: kNavy),
      titleSmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: kNavy),
      bodyLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          height: 1.5,
          color: kNavy.withAlpha(204)),
      bodyMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          height: 1.43,
          color: kNavy.withAlpha(204)),
      bodySmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          height: 1.33,
          color: kNavy.withAlpha(179)),
      labelLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: kNavy),
      labelMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: kNavy),
      labelSmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: kNavy),
    ),
  );

// تعريف اللون الأساسي (Seed Color) في متغير علشان نستخدمه في أكتر من مكان
// ألوان البذرة (Seed) — أزرق هادئ مناسب للوضع الداكن (تم تغيير الاسم لتجنب التكرار)

  // لون البذرة الأساسي للداكن

// تعريف ألوان البالتة

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    brightness: Brightness.dark, // تحديد الوضع داكن

    // === ColorScheme باستخدام البالتة ===
    colorScheme: ColorScheme.fromSeed(
      seedColor: kBlue, // استخدام kBlue كلون أساسي للحساب
      brightness: Brightness.dark,
    ).copyWith(
      // --- الألوان الرئيسية (Primary) - باستخدام kTeal كأكسنت ---
      primary: kTeal, // اللون الأساسي (الأزرق الفاتح الهادي)
      onPrimary: kNavy, // لون النص على الأولي ( Navy داكن علشان يبان عليه)
      primaryContainer:
          kIndigo, // لون حاوية الأولي (ممكن نستخدمه للبطاقات المميزة)
      onPrimaryContainer: Colors.white, // لون النص على حاوية الأولي

      // --- الألوان الثانوية (Secondary) - باستخدام kBlue ---
      secondary: kBlue, // اللون الثانوي (الأزرق الأساسي)
      onSecondary: Colors.white, // لون النص على الثانوي
      secondaryContainer: kBlue.withAlpha(51), // حاوية ثانوية أفتح
      onSecondaryContainer: Colors.white, // لون النص على حاوية الثانوي

      // --- الألوان الثالثية (Tertiary) - باستخدام kIndigo ---
      tertiary: kIndigo, // اللون الثالثي (البنفسجي)
      onTertiary: Colors.white, // لون النص على الثالثي
      tertiaryContainer: kIndigo.withAlpha(51), // حاوية ثالثية أفتح
      onTertiaryContainer: Colors.white, // لون النص على حاوية الثالثي

      // --- ألوان الخلفيات والأسطح ---
      surface: const Color(0xFF151A2E), // أسطح البطاقات والمكونات ( Navy داكن)
      onSurface: Colors.white, // نص على الأسطح
      surfaceContainerHighest:
          const Color(0xFF1C2341), // سطح متنوع ( чуть أفتح من surface)
      onSurfaceVariant: Colors.white70, // نص على السطح المتنوع

      // --- ألوان أخرى ---
      outline: const Color(0xFF2A3350), // حدود خفيفة ( Navy أفتح)
      outlineVariant:
          const Color(0xFF3A4360), // حدود متنوعة ( чуть أفتح من outline)
      shadow: Colors.black, // لون الظل
      scrim: Colors.black, // لون scrim (overlay)
      inverseSurface: Colors.white, // سطح معكوس (علشان الوضع الفاتح)
      onInverseSurface: kNavy, // نص على السطح المعكوس
      inversePrimary: kNavy, // أولي معكوس
      error: const Color(0xFFCF6679), // لون الخطأ (أحمر فاتح Material)
      onError: Colors.black, // نص على الخطأ
      errorContainer: const Color(0xFFB00020).withAlpha(51), // حاوية خطأ
      onErrorContainer: const Color(0xFFCF6679), // نص على حاوية الخطأ
    ),

    // === خلفية الشاشة ===
    scaffoldBackgroundColor:
        const Color(0xFF0F1220), // نفس خلفية الـ background

    // === AppBar ===
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 2,
      backgroundColor: Color(0xFF0F1220), // نفس خلفية الشاشة
      foregroundColor: Colors.white, // لون الأيقونات والنص
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),

    // === Card ===
    cardTheme: CardThemeData(
      elevation: 2,
      color: const Color(0xFF161C2B), // لون البطاقة ( чуть أفتح من surface)
      shadowColor: Colors.black.withAlpha(102), // ظل البطاقة
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: const Color(0xFF2A3350).withAlpha(128), // حد أخف للبطاقة
          width: 0.5,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    // === ElevatedButton ===
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kTeal, // لون الزرار (الأكسنت)
        foregroundColor: kNavy, // لون النص ( Navy داكن)
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBackgroundColor: kTeal.withAlpha(128),
        disabledForegroundColor: kNavy.withAlpha(128),
      ),
    ),

    // === OutlinedButton ===
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kTeal, // لون النص والحد (الأكسنت)
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(
          color: kTeal.withAlpha(179), // لون الحد
          width: 1.5,
        ),
        disabledForegroundColor: kTeal.withAlpha(128),
      ),
    ),

    // === TextButton ===
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kTeal, // لون النص (الأكسنت)
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
        ),
        disabledForegroundColor: kTeal.withAlpha(128),
      ),
    ),

    // === InputDecoration (TextFields, etc.) ===
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A2135), // خلفية الحقل ( чуть أفتح من surface)
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFF2A3350).withAlpha(179), // حد عادي
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFF2A3350).withAlpha(179), // حد مفعل
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: kTeal, // حد مختار (الأكسنت)
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFCF6679), // حد خطأ
          width: 2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFCF6679), // حد خطأ مختار
          width: 2,
        ),
      ),
      labelStyle: const TextStyle(color: Colors.white70),
      floatingLabelStyle: TextStyle(color: kTeal, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(color: Colors.white60),
      prefixIconColor: Colors.white60,
      suffixIconColor: Colors.white60,
    ),

    // === Switch ===
    switchTheme: SwitchThemeData(
      thumbColor:
          WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return kTeal; // لون الزرّاعة لما يكون مفعل (الأكسنت)
        }
        return Colors.white70; // لون الزرّاعة لما يكون مش مفعل
      }),
      trackColor:
          WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return kTeal
              .withAlpha(128); // لون الخلفية لما يكون مفعل (الأكسنت شفاف)
        }
        return const Color(0xFF2A3350)
            .withAlpha(128); // لون الخلفية لما يكون مش مفعل
      }),
    ),

    // === SnackBar ===
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1C2336), // خلفية الـ SnackBar
      contentTextStyle:
          const TextStyle(fontFamily: 'Cairo', color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 6,
    ),

    // === Divider ===
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2A3350), // لون الـ Divider
      thickness: 1,
      space: 1,
    ),

    // === TextTheme ===
    textTheme: TextTheme(
      displayLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 57,
          fontWeight: FontWeight.bold,
          color: Colors.white),
      displayMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 45,
          fontWeight: FontWeight.bold,
          color: Colors.white),
      displaySmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white),
      headlineLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white),
      headlineMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white),
      headlineSmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white),
      titleLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white),
      titleMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white),
      titleSmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white),
      bodyLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 16,
          height: 1.5,
          color: Colors.white70),
      bodyMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          height: 1.43,
          color: Colors.white70),
      bodySmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          height: 1.33,
          color: Colors.white60),
      labelLarge: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white),
      labelMedium: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white),
      labelSmall: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white),
    ),
  );
}
