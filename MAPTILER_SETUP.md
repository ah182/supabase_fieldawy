# 🗺️ دليل MapTiler - الأفضل للجودة العالية

## 🌟 لماذا MapTiler:

- ⭐⭐⭐⭐⭐ **جودة عالية جداً**
- 💰 **100,000 مشاهدة مجاناً** (ضعف Mapbox!)
- 🛰️ **صور ستلايت واضحة جداً**
- 🏘️ **أسماء القرى واضحة**
- 🏪 **أسماء المحلات والأماكن**
- ✅ **قانوني 100%**

---

## 🚀 الخطوات (3 دقائق):

### 1️⃣ التسجيل

🔗 **اذهب لـ:**
```
https://cloud.maptiler.com/auth/widget
```

**الخيارات:**
- سجّل بـ Email
- أو Google
- أو GitHub

**اضغط Sign Up**

---

### 2️⃣ الحصول على API Key

بعد التسجيل:

1. **اذهب لـ:**
   ```
   https://cloud.maptiler.com/account/keys/
   ```

2. **انسخ Default API key**
   - شكله: `abcd1234efgh5678`

---

### 3️⃣ ضع API Key في الكود

**افتح:**
```
lib/features/clinics/presentation/screens/clinics_map_screen.dart
```

**ابحث عن السطر ~21:**
```dart
static const String _mapTilerKey = 'YOUR_MAPTILER_KEY_HERE';
```

**استبدله بـ:**
```dart
static const String _mapTilerKey = 'abcd1234...'; // الـ key الخاص بك
```

---

### 4️⃣ شغّل التطبيق

```bash
flutter run
```

---

## 🎨 أنماط MapTiler المتاحة:

### 1. **Hybrid** (المُستخدم الآن) ⭐⭐⭐⭐⭐

**الأفضل للاستخدام العام!**

```dart
urlTemplate: 'https://api.maptiler.com/maps/hybrid/256/{z}/{x}/{y}.jpg?key=$_mapTilerKey'
```

**المميزات:**
- ✅ صور ستلايت عالية الجودة
- ✅ أسماء المدن والقرى واضحة جداً
- ✅ أسماء الشوارع
- ✅ المحلات والأماكن

---

### 2. **Streets** (خريطة عادية)

```dart
urlTemplate: 'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=$_mapTilerKey'
```

**المميزات:**
- ✅ ألوان واضحة
- ✅ كل الأسماء
- ✅ تفاصيل دقيقة
- ❌ ليس ستلايت

---

### 3. **Satellite** (صور فقط بدون أسماء)

```dart
urlTemplate: 'https://api.maptiler.com/maps/satellite/256/{z}/{x}/{y}.jpg?key=$_mapTilerKey'
```

**المميزات:**
- ✅ صور ستلايت نقية
- ❌ بدون أسماء

---

### 4. **Basic** (بسيط وخفيف)

```dart
urlTemplate: 'https://api.maptiler.com/maps/basic-v2/256/{z}/{x}/{y}.png?key=$_mapTilerKey'
```

**المميزات:**
- ✅ خفيف وسريع
- ✅ تصميم بسيط
- ⚠️ تفاصيل أقل

---

### 5. **Outdoor** (للطبيعة)

```dart
urlTemplate: 'https://api.maptiler.com/maps/outdoor-v2/256/{z}/{x}/{y}.png?key=$_mapTilerKey'
```

**المميزات:**
- ✅ تضاريس واضحة
- ✅ مسارات المشي
- ✅ مناطق طبيعية

---

### 6. **Topo** (طبوغرافي)

```dart
urlTemplate: 'https://api.maptiler.com/maps/topo-v2/256/{z}/{x}/{y}.png?key=$_mapTilerKey'
```

**المميزات:**
- ✅ خطوط الكنتور
- ✅ الارتفاعات
- ✅ مناسب للجيولوجيا

---

### 7. **Winter** (شتوي)

```dart
urlTemplate: 'https://api.maptiler.com/maps/winter-v2/256/{z}/{x}/{y}.png?key=$_mapTilerKey'
```

**المميزات:**
- ✅ تصميم شتوي
- ✅ ألوان باردة

---

## 🔄 التبديل بين الأنماط:

### إضافة زر تبديل في التطبيق:

```dart
enum MapTilerStyle {
  hybrid,
  streets,
  satellite,
  outdoor,
  basic,
}

class _ClinicsMapScreenState extends ConsumerState<ClinicsMapScreen> {
  static const String _mapTilerKey = 'YOUR_KEY_HERE';
  MapTilerStyle _currentStyle = MapTilerStyle.hybrid;

  String _getMapTilerUrl() {
    final base = 'https://api.maptiler.com/maps/';
    final style = switch (_currentStyle) {
      MapTilerStyle.hybrid => 'hybrid/256/{z}/{x}/{y}.jpg',
      MapTilerStyle.streets => 'streets-v2/256/{z}/{x}/{y}.png',
      MapTilerStyle.satellite => 'satellite/256/{z}/{x}/{y}.jpg',
      MapTilerStyle.outdoor => 'outdoor-v2/256/{z}/{x}/{y}.png',
      MapTilerStyle.basic => 'basic-v2/256/{z}/{x}/{y}.png',
    };
    return '$base$style?key=$_mapTilerKey';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خريطة العيادات'),
        actions: [
          PopupMenuButton<MapTilerStyle>(
            icon: const Icon(Icons.layers),
            onSelected: (style) => setState(() => _currentStyle = style),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: MapTilerStyle.hybrid,
                child: Text('🛰️ ستلايت + أسماء (الأفضل)'),
              ),
              PopupMenuItem(
                value: MapTilerStyle.streets,
                child: Text('🗺️ خريطة عادية'),
              ),
              PopupMenuItem(
                value: MapTilerStyle.satellite,
                child: Text('📸 صور فقط'),
              ),
              PopupMenuItem(
                value: MapTilerStyle.outdoor,
                child: Text('🏔️ طبيعة'),
              ),
              PopupMenuItem(
                value: MapTilerStyle.basic,
                child: Text('📋 بسيط'),
              ),
            ],
          ),
        ],
      ),
      body: FlutterMap(
        children: [
          TileLayer(
            urlTemplate: _getMapTilerUrl(),
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

| الاستخدام | الحد المجاني |
|-----------|--------------|
| **Tile Loads** | 100,000 / شهر |
| Geocoding | 100,000 / شهر |
| Vector Tiles | 100,000 / شهر |

**أكثر سخاءً من Mapbox بالضعف!** 💰

---

## 🔒 حماية API Key:

### في MapTiler Dashboard:

1. اذهب لـ: https://cloud.maptiler.com/account/keys/
2. اختر الـ Key
3. أضف Restrictions:
   - **HTTP Referrers:** `com.fieldawy.store`

---

## 📈 مراقبة الاستخدام:

**Dashboard:**
```
https://cloud.maptiler.com/usage/
```

شوف:
- عدد الطلبات اليومية
- الباقي من الحد المجاني
- احصائيات مفصلة

---

## 🎯 مقارنة شاملة:

| المقدم | الحد المجاني | الجودة | الأسماء | قانوني |
|--------|-------------|--------|---------|--------|
| **MapTiler** | **100k** ⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ |
| Mapbox | 50k | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ |
| ESRI | غير محدد | ⭐⭐⭐ | ⭐⭐⭐ | ✅ |
| Google (SDK) | مدفوع | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ مدفوع |

**MapTiler = الأفضل قيمة مقابل المال!** 🏆

---

## ✅ Checklist:

- [ ] سجلت في MapTiler
- [ ] نسخت API Key
- [ ] وضعت الـ Key في الكود
- [ ] شغلت `flutter run`
- [ ] الخريطة ظهرت بجودة عالية! 🎉

---

## 🔗 روابط مهمة:

- **التسجيل:** https://cloud.maptiler.com/auth/widget
- **API Keys:** https://cloud.maptiler.com/account/keys/
- **الاستخدام:** https://cloud.maptiler.com/usage/
- **Documentation:** https://docs.maptiler.com/

---

## 🐛 حل المشاكل:

### الخريطة لا تظهر؟
1. تأكد من API key صحيح
2. تأكد من الإنترنت يعمل
3. شوف console للأخطاء

### "403 Forbidden"؟
- الـ key غلط أو expired
- انسخه مرة تانية

### "429 Too Many Requests"؟
- وصلت للحد (100k)
- انتظر الشهر القادم
- أو ترقية للخطة المدفوعة

---

## 🎉 النتيجة المتوقعة:

**بعد التطبيق ستحصل على:**
- 🛰️ صور ستلايت بجودة ممتازة
- 🏘️ أسماء القرى واضحة جداً
- 🏪 أسماء المحلات والأماكن
- 🛣️ جميع الشوارع
- 📊 أداء سريع
- 💰 حد أعلى (100k بدلاً من 50k)

**MapTiler = خيارك الأفضل!** 🚀✨
