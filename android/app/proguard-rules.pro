# ML Kit Text Recognition rules
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# OkHttp rules (often required by uCrop or other image pickers)
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }

# Google Play Core rules (Required by Flutter engine)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# General ProGuard rules for Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Sign-In & Firebase
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.api.** { *; }

# Supabase (if applicable for native parts)
-keep class io.supabase.** { *; }

# Prevent R8 from stripping generic types in JSON serialization (common issue)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Coroutines (if used by plugins)
-keep class kotlinx.coroutines.** { *; }
