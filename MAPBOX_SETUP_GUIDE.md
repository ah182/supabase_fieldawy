# 🗺️ دليل إعداد Mapbox (خطوة بخطوة)

## ✅ المميزات:
- ⭐⭐⭐⭐⭐ أفضل دقة متاحة
- 🏘️ أسماء القرى الصغيرة واضحة
- 🏪 أسماء المحلات والأماكن
- 🛣️ تفاصيل الشوارع
- 💰 **مجاني حتى 50,000 مشاهدة شهرياً**

---

## 🚀 الخطوات:

### 1. إنشاء حساب مجاني

1. **اذهب إلى:** https://account.mapbox.com/auth/signup/

2. **املأ البيانات:**
   - Email
   - Username
   - Password
   - قبول الشروط

3. **اضغط Get Started**

4. **تحقق من البريد الإلكتروني** (افتح الرسالة وفعّل الحساب)

---

### 2. الحصول على Access Token

بعد تسجيل الدخول:

1. **ستجد Dashboard**
2. **انسخ "Default public token"** (يبدأ بـ `pk.eyJ...`)
3. **أو اذهب لـ:** https://account.mapbox.com/access-tokens/

**شكل الـ Token:**
```
pk.eyJ1IjoieW91cnVzZXJuYW1lIiwiYSI6ImNrZjN4eXo5YTBhejEyeW80Nm1rbm1qbGQifQ.abc123xyz
```

---

### 3. تطبيق Mapbox في الكود

بعد ما تحصل على الـ Token:

1. **افتح الملف:**
   ```
   lib/features/clinics/presentation/screens/clinics_map_screen.dart
   ```

2. **استبدل TileLayer الحالي بـ:**

```dart
// في أول الملف، أضف الـ token
class _ClinicsMapScreenState extends ConsumerState<ClinicsMapScreen> {
  // ضع الـ Token هنا
  static const String _mapboxToken = 'pk.YOUR_TOKEN_HERE'; // ⬅️ ضع token هنا
  
  // ... باقي الكود
  
  @override
  Widget build(BuildContext context) {
    // ...
    
    children: [
      // Mapbox Satellite Streets
      TileLayer(
        urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
        userAgentPackageName: 'com.fieldawy.store',
        maxZoom: 22,
        tileProvider: NetworkTileProvider(),
      ),
      MarkerLayer(markers: _markers),
      RichAttributionWidget(
        attributions: [
          TextSourceAttribution(
            '© Mapbox © OpenStreetMap',
            onTap: () {},
          ),
        ],
      ),
    ],
  }
}
```

---

### 4. أنماط Mapbox المتاحة

يمكنك استخدام أي من هذه الأنماط:

#### A. Satellite Streets (الأفضل - ستلايت + أسماء) ⭐
```dart
'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken'
```

#### B. Streets (خريطة عادية ملونة)
```dart
'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken'
```

#### C. Outdoors (للطبيعة والمناطق الخارجية)
```dart
'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken'
```

#### D. Light (فاتح وبسيط)
```dart
'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxToken'
```

#### E. Dark (غامق)
```dart
'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxToken'
```

---

## 🎨 إضافة زر لتبديل الأنماط (اختياري)

```dart
enum MapboxStyle {
  satelliteStreets,
  streets,
  outdoors,
  light,
  dark,
}

class _ClinicsMapScreenState extends ConsumerState<ClinicsMapScreen> {
  static const String _mapboxToken = 'pk.YOUR_TOKEN_HERE';
  MapboxStyle _currentStyle = MapboxStyle.satelliteStreets;

  String _getMapboxUrl() {
    switch (_currentStyle) {
      case MapboxStyle.satelliteStreets:
        return 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken';
      case MapboxStyle.streets:
        return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken';
      case MapboxStyle.outdoors:
        return 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken';
      case MapboxStyle.light:
        return 'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxToken';
      case MapboxStyle.dark:
        return 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxToken';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خريطة العيادات'),
        actions: [
          // زر تغيير نمط الخريطة
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.satellite),
                      title: const Text('ستلايت + أسماء'),
                      onTap: () {
                        setState(() => _currentStyle = MapboxStyle.satelliteStreets);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.map),
                      title: const Text('خريطة عادية'),
                      onTap: () {
                        setState(() => _currentStyle = MapboxStyle.streets);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.terrain),
                      title: const Text('طبيعة'),
                      onTap: () {
                        setState(() => _currentStyle = MapboxStyle.outdoors);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.wb_sunny),
                      title: const Text('فاتح'),
                      onTap: () {
                        setState(() => _currentStyle = MapboxStyle.light);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.nightlight),
                      title: const Text('غامق'),
                      onTap: () {
                        setState(() => _currentStyle = MapboxStyle.dark);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: FlutterMap(
        children: [
          TileLayer(
            urlTemplate: _getMapboxUrl(),
            maxZoom: 22,
          ),
          MarkerLayer(markers: _markers),
        ],
      ),
    );
  }
}
```

---

## 📊 الحدود المجانية:

| الاستخدام | الحد المجاني | السعر بعد الحد |
|-----------|-------------|----------------|
| Map Loads | 50,000 / شهر | $5 لكل 1000 إضافي |
| Geocoding | 100,000 / شهر | $0.50 لكل 1000 إضافي |
| Directions | 100,000 / شهر | $0.50 لكل 1000 إضافي |

**50,000 مشاهدة شهرياً = كافية جداً لتطبيق صغير/متوسط!**

---

## 🔒 حماية الـ Token:

⚠️ **مهم:** الـ Public Token آمن للاستخدام في التطبيق

**لكن للأمان الإضافي:**

1. **حدد URL Restrictions في Mapbox Dashboard:**
   - اذهب لـ: https://account.mapbox.com/access-tokens/
   - اختر الـ Token
   - أضف: `com.fieldawy.store://` في URL restrictions

2. **راقب الاستخدام:**
   - Dashboard → Statistics
   - شوف عدد الطلبات يومياً

---

## 🐛 حل المشاكل:

### ❌ الخريطة لا تظهر / شاشة فارغة
**الحل:**
1. تأكد من الـ token صحيح
2. تأكد من الإنترنت يعمل
3. شوف console للأخطاء:
   ```bash
   flutter run -v | grep -i "mapbox\|tile\|error"
   ```

### ❌ رسالة "401 Unauthorized"
**الحل:**
- الـ Token غلط أو غير صحيح
- انسخه مرة تانية من Dashboard

### ❌ رسالة "429 Too Many Requests"
**الحل:**
- وصلت للحد المجاني (50k)
- انتظر بداية الشهر القادم
- أو ترقية للخطة المدفوعة

---

## ✅ Checklist:

- [ ] سجلت حساب في Mapbox
- [ ] فعّلت البريد الإلكتروني
- [ ] نسخت الـ Access Token
- [ ] وضعت الـ Token في الكود
- [ ] شغّلت `flutter run`
- [ ] الخريطة ظهرت بنجاح! 🎉

---

## 📞 روابط مفيدة:

- **التسجيل:** https://account.mapbox.com/auth/signup/
- **Dashboard:** https://account.mapbox.com/
- **Tokens:** https://account.mapbox.com/access-tokens/
- **الاستخدام:** https://account.mapbox.com/statistics/
- **Documentation:** https://docs.mapbox.com/

---

## 🎯 بعد التطبيق:

**ستحصل على:**
- ⭐⭐⭐⭐⭐ أفضل جودة خرائط
- 🏘️ أسماء القرى الصغيرة واضحة
- 🏪 أسماء المحلات والأماكن
- 🛣️ جميع الشوارع والطرق
- 🎨 أنماط متعددة

**قانوني 100% ومجاني حتى 50k/شهر!** ✅🚀
