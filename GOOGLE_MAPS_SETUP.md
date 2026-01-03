# 🗺️ إعداد Google Maps API (خطوة بخطوة)

## 🎯 النظام الجديد:

```
Google Maps SDK (رسمي وقانوني)
$200 مجاناً شهرياً = ~28,000 تحميل
أفضل جودة ممكنة
       ↓
عند $175 (90% من الحد)
       ↓
Flutter Map + ESRI
مجاني بلا حدود
جودة ممتازة
```

---

## ⚙️ الخطوات:

### 1️⃣ إنشاء مشروع Google Cloud (مجاني)

1. **اذهب إلى:**
   ```
   https://console.cloud.google.com/
   ```

2. **إنشاء مشروع جديد:**
   - اضغط "Select a project" → "New Project"
   - اسم المشروع: `Fieldawy Store`
   - اضغط "Create"

3. **تفعيل Billing:**
   - اذهب لـ Billing
   - ربط بطاقة ائتمان (لن يتم الخصم - مجاني حتى $200)
   - ✅ Google تعطيك $200 مجاناً كل شهر!

---

### 2️⃣ تفعيل Maps SDK

1. **اذهب إلى:**
   ```
   https://console.cloud.google.com/apis/library
   ```

2. **ابحث عن وفعّل:**
   - ✅ **Maps SDK for Android**
   - ✅ **Maps SDK for iOS**
   - ✅ **Maps JavaScript API** (للويب)

---

### 3️⃣ إنشاء API Keys

1. **اذهب إلى:**
   ```
   https://console.cloud.google.com/apis/credentials
   ```

2. **Create Credentials** → **API Key**

3. **سيظهر API Key - انسخه!**
   ```
   مثال: AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

4. **Restrict the key (مهم للأمان):**
   - Edit API key
   - **Application restrictions:**
     - Android: ضع SHA-1 fingerprint
     - iOS: ضع Bundle ID: `com.fieldawy.app`
   - **API restrictions:**
     - Restrict key
     - اختر:
       - Maps SDK for Android
       - Maps SDK for iOS
   - Save

---

### 4️⃣ الحصول على SHA-1 Fingerprint (Android)

في Terminal:

```bash
cd android
./gradlew signingReport
```

**انسخ SHA-1** من output:
```
SHA1: AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00:AA:BB:CC:DD
```

ضعه في Google Console → API Key restrictions

---

### 5️⃣ إضافة API Key للمشروع

#### Android:

**ملف:** `android/app/src/main/AndroidManifest.xml`

```xml
<manifest>
    <application>
        <!-- ضع قبل </application> -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_ANDROID_API_KEY_HERE"/>
    </application>
</manifest>
```

#### iOS:

**ملف:** `ios/Runner/AppDelegate.swift`

```swift
import UIKit
import Flutter
import GoogleMaps  // ✅ أضف هذا

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_IOS_API_KEY_HERE")  // ✅ أضف هذا
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

---

### 6️⃣ تحديث Podfile (iOS)

**ملف:** `ios/Podfile`

أضف في أول الملف:
```ruby
platform :ios, '14.0'  # ✅ تأكد من هذا السطر
```

ثم شغّل:
```bash
cd ios
pod install
```

---

### 7️⃣ تحديث build.gradle (Android)

**ملف:** `android/app/build.gradle`

تأكد من:
```gradle
android {
    compileSdkVersion 34  // ✅ على الأقل 33
    
    defaultConfig {
        minSdkVersion 21  // ✅ على الأقل 21
        targetSdkVersion 34
    }
}
```

---

### 8️⃣ تشغيل flutter pub get

```bash
flutter pub get
```

---

## 🎯 بعد الإعداد:

الكود جاهز! التطبيق سيستخدم:
- ✅ **Google Maps SDK** حتى 28k تحميل
- ✅ **Flutter Map + ESRI** بعد ذلك

---

## 💰 الحد المجاني:

| الخدمة | الحد المجاني | السعر بعد الحد |
|--------|-------------|----------------|
| **Google Maps** | $200 / شهر | $7 / 1000 load |
| تحميلات الخريطة | ~28,000 / شهر | $0.007 / load |

**مع 28k تحميل:**
- ✅ مجاني تماماً
- ✅ بعد ذلك → ESRI (مجاني للأبد)

---

## 📊 مراقبة الاستخدام:

### في Google Cloud Console:

```
https://console.cloud.google.com/billing
```

**اضبط Budget Alert:**
1. Billing → Budgets & alerts
2. Create budget
3. Amount: $180 (90% من $200)
4. Alert: Email عند الوصول لـ 90%

---

## 🔒 الأمان:

### API Key Restrictions (مهم جداً!):

1. **Android restrictions:**
   - Add SHA-1 fingerprint
   - Add package name: `com.example.fieldawy_store`

2. **iOS restrictions:**
   - Add Bundle ID: `com.fieldawy.app`

3. **API restrictions:**
   - Restrict to:
     - Maps SDK for Android
     - Maps SDK for iOS
     - Maps JavaScript API (للويب)

---

## ✅ Checklist:

- [ ] أنشأت مشروع Google Cloud
- [ ] فعّلت Billing (ربط بطاقة)
- [ ] فعّلت Maps SDK for Android
- [ ] فعّلت Maps SDK for iOS
- [ ] أنشأت API Key
- [ ] وضعت restrictions على الـ Key
- [ ] أضفت API Key في AndroidManifest.xml
- [ ] أضفت API Key في AppDelegate.swift
- [ ] شغلت `flutter pub get`
- [ ] شغلت `pod install` (iOS)
- [ ] اختبرت التطبيق ✅

---

## 🐛 حل المشاكل:

### الخريطة لا تظهر (Android):

1. تأكد من API Key في AndroidManifest.xml
2. تأكد من SHA-1 في Google Console
3. تأكد من تفعيل Maps SDK for Android
4. شوف Logcat للأخطاء

### الخريطة لا تظهر (iOS):

1. تأكد من API Key في AppDelegate.swift
2. تأكد من `pod install`
3. تأكد من Bundle ID في Google Console
4. تأكد من تفعيل Maps SDK for iOS

---

## 📞 روابط مفيدة:

- **Google Cloud Console:** https://console.cloud.google.com/
- **APIs Library:** https://console.cloud.google.com/apis/library
- **Credentials:** https://console.cloud.google.com/apis/credentials
- **Billing:** https://console.cloud.google.com/billing
- **Google Maps Pricing:** https://mapsplatform.google.com/pricing/

---

**بعد الإعداد، شغّل التطبيق - سيستخدم Google Maps الرسمي!** 🗺️✨
