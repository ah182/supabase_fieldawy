# ⚡ Mapbox - البداية السريعة

## 🚀 3 خطوات فقط:

### 1️⃣ التسجيل (دقيقة واحدة)
```
https://account.mapbox.com/auth/signup/
```
- ضع email
- اختر username وpassword
- اضغط Get Started

### 2️⃣ نسخ الـ Token
بعد التسجيل مباشرة:
- ستجد **Default public token**
- انسخه (يبدأ بـ `pk.eyJ...`)

### 3️⃣ وضع الـ Token في الكود

**افتح:**
```
lib/features/clinics/presentation/screens/clinics_map_screen.dart
```

**ابحث عن:** (في السطر رقم ~20)
```dart
static const String _mapboxToken = 'YOUR_MAPBOX_TOKEN_HERE';
```

**استبدلها بـ:**
```dart
static const String _mapboxToken = 'pk.eyJ1Ijoi....';  // الـ token الخاص بك
```

**مثال:**
```dart
static const String _mapboxToken = 'pk.eyJ1IjoibXl1c2VybmFtZSIsImEiOiJja2xqNWh6YjIwMTY5MnBudm1hNGp5ZjJ3In0.abcd1234efgh5678';
```

---

## ✅ انتهيت؟ شغّل التطبيق:

```bash
flutter run
```

---

## 🎉 النتيجة:

سترى:
- ✅ صور ستلايت بجودة عالية جداً
- ✅ أسماء المدن والمحافظات
- ✅ أسماء القرى الصغيرة
- ✅ أسماء الشوارع
- ✅ المحلات والأماكن
- ✅ كل التفاصيل واضحة!

---

## ❌ إذا لم تظهر الخريطة:

### المشكلة: شاشة فارغة
**الحل:**
1. تأكد من وضع الـ token صحيح
2. تأكد من الإنترنت يعمل
3. شوف console للأخطاء

### المشكلة: "401 Unauthorized"
**الحل:**
- الـ token غلط
- انسخه مرة تانية من: https://account.mapbox.com/access-tokens/

---

## 📊 الحدود المجانية:

✅ **50,000 مشاهدة شهرياً مجاناً**

يعني:
- ~1,600 مشاهدة يومياً
- كافي لتطبيق صغير/متوسط

راقب الاستخدام من:
```
https://account.mapbox.com/statistics/
```

---

## 🎨 أنماط أخرى (اختياري):

### خريطة عادية ملونة:
استبدل السطر في TileLayer:
```dart
urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
```

### خريطة للطبيعة:
```dart
urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
```

### خريطة فاتحة:
```dart
urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
```

---

## ✅ Checklist:

- [ ] سجلت في Mapbox
- [ ] نسخت الـ Token
- [ ] وضعته في الكود (استبدلت `YOUR_MAPBOX_TOKEN_HERE`)
- [ ] شغلت `flutter run`
- [ ] الخريطة ظهرت! 🎉

---

## 🔗 روابط مهمة:

- **التسجيل:** https://account.mapbox.com/auth/signup/
- **الـ Tokens:** https://account.mapbox.com/access-tokens/
- **الإحصائيات:** https://account.mapbox.com/statistics/

**بالتوفيق! 🚀**
