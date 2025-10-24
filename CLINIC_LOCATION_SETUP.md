# 📍 دليل إعداد نظام تحديد موقع العيادات

## نظرة عامة

تم إضافة نظام كامل لتحديد موقع العيادات الخاص بالأطباء البيطريين مع الميزات التالية:

✅ **للأطباء:**
- طلب تلقائي للموقع عند أول تسجيل دخول
- زر تحديث الموقع في صفحة الإعدادات
- حفظ موقع العيادة تلقائياً مع العنوان ورقم الهاتف

✅ **لجميع المستخدمين:**
- عرض جميع العيادات على خريطة تفاعلية (OpenStreetMap)
- معلومات تفصيلية لكل عيادة (الاسم، العنوان، الهاتف، واتساب)
- إمكانية الحصول على الاتجاهات

🎉 **مجاني تماماً**: يستخدم OpenStreetMap - لا حاجة لـ API key!

---

## 📋 خطوات الإعداد

### 1️⃣ تثبيت الحزم الجديدة

قم بتشغيل الأمر التالي لتثبيت الحزم المطلوبة:

```bash
flutter pub get
```

الحزم التي تم إضافتها:
- `geolocator: ^12.0.0` - للحصول على الموقع
- `flutter_map: ^7.0.2` - لعرض الخرائط (OpenStreetMap)
- `latlong2: ^0.9.0` - للتعامل مع الإحداثيات
- `geocoding: ^3.0.0` - لتحويل الإحداثيات إلى عناوين

---

### 2️⃣ إنشاء جدول Clinics في Supabase

1. افتح لوحة تحكم Supabase الخاصة بك
2. اذهب إلى **SQL Editor**
3. قم بتشغيل الملف التالي:

```
supabase/migrations/20250127_create_clinics_table.sql
```

أو انسخ والصق محتوى الملف في SQL Editor وقم بتشغيله.

هذا سيقوم بإنشاء:
- ✅ جدول `clinics` مع جميع الأعمدة المطلوبة
- ✅ Indexes للأداء الأفضل
- ✅ Row Level Security (RLS) policies
- ✅ Trigger لتحديث `updated_at` تلقائياً

---

### 3️⃣ الأذونات (Permissions)

#### ✅ Android Permissions (تم إضافتها مسبقاً):
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_BACKGROUND_LOCATION`

الملف: `android/app/src/main/AndroidManifest.xml`

#### ✅ iOS Permissions (تم إضافتها مسبقاً):
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

الملف: `ios/Runner/Info.plist`

**ملاحظة:** إذا لم يتم إضافة أذونات iOS تلقائياً، راجع الملف `IOS_PERMISSIONS_SETUP.md`

---

## 🚀 كيفية الاستخدام

### للأطباء:

#### **1. عند أول تسجيل دخول:**
- سيظهر تلقائياً مربع حوار يطلب الإذن بتحديد موقع العيادة
- عند الموافقة، سيتم حفظ الموقع تلقائياً مع العنوان

#### **2. تحديث الموقع لاحقاً:**
- اذهب إلى **الإعدادات**
- في قسم "موقع العيادة"
- اضغط على **"تحديث موقع العيادة"**
- وافق على الأذونات وسيتم تحديث الموقع

---

### لجميع المستخدمين:

#### **عرض خريطة العيادات:**

1. اذهب إلى **الإعدادات**
2. في قسم "الخدمات"
3. اضغط على **"خريطة العيادات"**

أو يمكن إضافة رابط في القائمة الرئيسية (Menu) حسب الحاجة.

#### **في شاشة الخريطة:**
- 🗺️ شاهد جميع العيادات على الخريطة
- 📍 اضغط على أي علامة (marker) لعرض معلومات العيادة
- 📞 اطلع على رقم الهاتف وواتساب
- 🧭 احصل على الاتجاهات للعيادة

---

## 📁 الملفات التي تم إضافتها

### Domain (Models):
- `lib/features/clinics/domain/clinic_model.dart`

### Data (Repository):
- `lib/features/clinics/data/clinic_repository.dart`

### Presentation (UI):
- `lib/features/clinics/presentation/screens/clinics_map_screen.dart`
- `lib/features/clinics/presentation/widgets/location_permission_dialog.dart`

### Core Services:
- `lib/core/services/location_service.dart`

### Database:
- `supabase/migrations/20250127_create_clinics_table.sql`

### Configuration:
- تحديثات في `pubspec.yaml`
- تحديثات في `android/app/src/main/AndroidManifest.xml`
- تحديثات في `ios/Runner/Info.plist`
- تحديثات في `lib/features/authentication/presentation/screens/auth_gate.dart`
- تحديثات في `lib/features/settings/presentation/screens/settings_screen.dart`

---

## 🔧 استكشاف الأخطاء

### **المشكلة:** الخريطة لا تظهر
**الحل:**
1. تحقق من وجود إنترنت نشط
2. تأكد من أن تطبيقك لديه إذن للوصول للإنترنت
3. جرّب إعادة تشغيل التطبيق

### **المشكلة:** لا يتم طلب أذونات الموقع
**الحل:**
1. تأكد من إضافة الأذونات في AndroidManifest.xml و Info.plist
2. على Android 11+، تأكد من منح الأذونات من إعدادات النظام
3. جرّب حذف التطبيق وإعادة تثبيته

### **المشكلة:** "Permission denied" عند حفظ الموقع في Supabase
**الحل:**
1. تأكد من تشغيل SQL migration file بشكل صحيح
2. تحقق من RLS policies في Supabase
3. تأكد من أن المستخدم مسجل دخول ودوره "doctor"

### **المشكلة:** العنوان لا يظهر
**الحل:**
1. تحقق من وجود اتصال إنترنت نشط
2. بعض المواقع النائية قد لا يتوفر لها عناوين دقيقة
3. خدمة Geocoding قد تأخذ بعض الوقت

---

## 📊 بنية قاعدة البيانات

### جدول `clinics`:

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | Foreign key إلى `auth.users` |
| `clinic_name` | TEXT | اسم العيادة (عادة نفس اسم الطبيب) |
| `latitude` | DOUBLE | خط العرض |
| `longitude` | DOUBLE | خط الطول |
| `address` | TEXT | العنوان (من geocoding) |
| `phone_number` | TEXT | رقم الهاتف |
| `created_at` | TIMESTAMP | تاريخ الإنشاء |
| `updated_at` | TIMESTAMP | تاريخ آخر تحديث |

---

## 🔐 الأمان (RLS Policies)

تم إعداد الـ policies التالية:

1. **القراءة (SELECT):** الجميع يمكنهم رؤية جميع العيادات
2. **الإضافة (INSERT):** فقط الأطباء يمكنهم إضافة عياداتهم
3. **التحديث (UPDATE):** فقط الطبيب يمكنه تحديث عيادته الخاصة
4. **الحذف (DELETE):** فقط الطبيب يمكنه حذف عيادته الخاصة
5. **الأدمن:** له صلاحيات كاملة على جميع العيادات

---

## 🎯 الميزات المستقبلية (اختياري)

يمكنك إضافة الميزات التالية لاحقاً:

- [ ] تقييمات للعيادات
- [ ] ساعات العمل
- [ ] صور للعيادة
- [ ] التخصصات البيطرية
- [ ] البحث عن عيادات قريبة
- [ ] فلترة حسب النوع أو التخصص
- [ ] إضافة عدة فروع لنفس الطبيب

---

## 📞 الدعم

إذا واجهت أي مشكلة:
1. راجع قسم استكشاف الأخطاء أعلاه
2. تحقق من console logs في التطبيق
3. راجع Supabase logs للتحقق من RLS policies

---

## ✅ Checklist للإعداد

- [ ] تشغيل `flutter pub get`
- [ ] تشغيل SQL migration في Supabase
- [ ] التحقق من الأذونات في AndroidManifest.xml
- [ ] التحقق من الأذونات في Info.plist (راجع IOS_PERMISSIONS_SETUP.md)
- [ ] اختبار طلب الموقع للطبيب
- [ ] اختبار عرض الخريطة
- [ ] اختبار تحديث الموقع من الإعدادات

## 🌍 حول OpenStreetMap

هذا التطبيق يستخدم [OpenStreetMap](https://www.openstreetmap.org/) لعرض الخرائط:
- ✅ مجاني تماماً - لا حاجة لـ API keys
- ✅ مفتوح المصدر
- ✅ تحديثات مستمرة من المجتمع
- ✅ يعمل بدون حدود للاستخدام

**ملاحظة:** OpenStreetMap يعتمد على مساهمات المجتمع، لذا قد تكون بعض المناطق النائية غير مفصلة كما في خرائط أخرى.

---

**تم بنجاح! 🎉**

الآن التطبيق جاهز لاستخدام نظام تحديد موقع العيادات.
