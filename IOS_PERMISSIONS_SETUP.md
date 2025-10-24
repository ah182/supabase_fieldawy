# إعداد أذونات iOS للموقع

## الخطوات المطلوبة:

### تحديث Info.plist

افتح الملف التالي:
```
ios/Runner/Info.plist
```

**أضف الأسطر التالية قبل السطر الأخير `</dict>`:**

```xml
<!-- Location Permissions for Clinic Location Feature -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>نحتاج إلى موقعك لتحديد موقع عيادتك على الخريطة وعرضها للمستخدمين الآخرين</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>نحتاج إلى موقعك لتحديد موقع عيادتك على الخريطة وعرضها للمستخدمين الآخرين</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>نحتاج إلى موقعك لتحديد موقع عيادتك على الخريطة وعرضها للمستخدمين الآخرين</string>
```

**الملف النهائي يجب أن يكون بهذا الشكل:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- المحتوى الموجود ... -->
    
    <key>UIStatusBarHidden</key>
    <false/>
    
    <!-- أضف هنا -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>نحتاج إلى موقعك لتحديد موقع عيادتك على الخريطة وعرضها للمستخدمين الآخرين</string>
    
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>نحتاج إلى موقعك لتحديد موقع عيادتك على الخريطة وعرضها للمستخدمين الآخرين</string>
    
    <key>NSLocationAlwaysUsageDescription</key>
    <string>نحتاج إلى موقعك لتحديد موقع عيادتك على الخريطة وعرضها للمستخدمين الآخرين</string>
</dict>
</plist>
```

---

## ملاحظات مهمة:

1. **لا حاجة لـ API Key**: نستخدم OpenStreetMap المجاني!
2. **قم بإعادة Build** للتطبيق بعد إضافة الأذونات
3. تأكد من أن التطبيق لديه أذونات الإنترنت

---

## اختبار:

بعد إضافة الأذونات:

### للمحاكي (Simulator):
```bash
flutter run
```

### للجهاز الفعلي:
1. قم بحذف التطبيق من الجهاز
2. قم بإعادة تشغيل:
   ```bash
   flutter clean
   flutter pub get
   cd ios
   pod install
   cd ..
   flutter run
   ```
3. سجل دخول كطبيب
4. يجب أن يظهر طلب الموقع تلقائياً

---

## Podfile (iOS)

إذا واجهت مشاكل في iOS، تأكد من أن `ios/Podfile` يحتوي على:

```ruby
platform :ios, '13.0'
```

ثم قم بتشغيل:
```bash
cd ios
pod deintegrate
pod install
cd ..
```
