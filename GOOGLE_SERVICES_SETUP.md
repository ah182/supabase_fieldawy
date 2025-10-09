# 🔥 Google Services Plugin - إعداد Firebase

## ✅ الإعداد الحالي

تم بالفعل تثبيت وإعداد Google Services plugin في مشروعك! 🎉

---

## 📋 الملفات والإعدادات الموجودة:

### 1️⃣ `android/settings.gradle.kts` - تعريف Plugin

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    // ✅ Google Services Plugin
    id("com.google.gms.google-services") version "4.3.15" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}
```

**الإصدار**: `4.3.15` (أحدث إصدار مستقر)

---

### 2️⃣ `android/app/build.gradle.kts` - تطبيق Plugin

```kotlin
plugins {
    id("com.android.application")
    // ✅ تطبيق Google Services
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
```

---

### 3️⃣ `android/app/google-services.json` - ملف التكوين

✅ **الملف موجود** في المسار الصحيح: `android/app/google-services.json`

هذا الملف يحتوي على:
- معرف المشروع في Firebase
- API Keys
- Client IDs
- معلومات التطبيق

---

## 🚀 كيفية التحقق من الإعداد

### 1. تشغيل Gradle Sync

```bash
cd D:\fieldawy_store
flutter clean
flutter pub get
cd android
./gradlew clean
./gradlew build
```

### 2. فحص أي أخطاء

إذا كان كل شيء صحيح، يجب أن يمر Build بدون أخطاء.

---

## 📦 الحزم المطلوبة في `pubspec.yaml`

تأكد من وجود حزم Firebase في `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase Core (إجباري)
  firebase_core: ^3.8.1
  
  # Firebase Services (حسب الحاجة)
  firebase_auth: ^5.3.3
  cloud_firestore: ^5.5.2
  firebase_storage: ^12.3.8
  firebase_messaging: ^15.1.5
```

---

## 🔧 ما الذي تم تعديله؟

### قبل التعديل:
```kotlin
flutter {
    source = "../.."
}
apply plugin: 'com.google.gms.google-services'  // ❌ سطر مكرر وقديم (Groovy syntax)
```

### بعد التعديل:
```kotlin
flutter {
    source = "../.."
}
// ✅ تم حذف السطر المكرر لأن Plugin مطبّق في أعلى الملف
```

**السبب:**
- في Kotlin DSL (`.gradle.kts`)، نستخدم `plugins { }` block في الأعلى
- السطر `apply plugin: 'com.google.gms.google-services'` هو Groovy syntax وكان مكرراً

---

## 🎯 الخطوات التالية

### إذا كنت تستخدم Firebase لأول مرة:

1. **تهيئة Firebase في التطبيق:**

```dart
// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(MyApp());
}
```

2. **توليد ملف Firebase Options:**

```bash
flutter pub global activate flutterfire_cli
flutterfire configure
```

هذا سيولّد ملف `lib/firebase_options.dart` تلقائياً.

---

## 🐛 استكشاف الأخطاء

### خطأ: "google-services.json is missing"
**الحل:** تأكد أن الملف موجود في `android/app/google-services.json`

### خطأ: "Plugin not found"
**الحل:** قم بتشغيل:
```bash
cd android
./gradlew clean
./gradlew build
```

### خطأ: "Duplicate class"
**الحل:** تأكد من عدم وجود سطر `apply plugin` مكرر

---

## 📚 المراجع

- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Android Setup](https://firebase.google.com/docs/android/setup)
- [Google Services Plugin](https://developers.google.com/android/guides/google-services-plugin)

---

## ✅ الحالة النهائية

| المتطلب | الحالة |
|---------|--------|
| Google Services Plugin | ✅ مثبت (v4.3.15) |
| Plugin في app/build.gradle.kts | ✅ مطبّق |
| google-services.json | ✅ موجود |
| التكوين الصحيح | ✅ جاهز |
| أخطاء Syntax | ✅ تم إصلاحها |

---

**🎉 مشروعك جاهز لاستخدام Firebase!**
