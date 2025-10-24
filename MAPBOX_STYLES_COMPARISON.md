# 🗺️ مقارنة أنماط Mapbox

## المشكلة:
أسماء القرى لا تظهر في نمط Satellite Streets

## ✅ الحل المُطبّق: Streets Style

تم تغيير النمط من:
```dart
// ❌ القديم - satellite-streets (أسماء غير واضحة)
'satellite-streets-v12'
```

إلى:
```dart
// ✅ الجديد - streets (كل الأسماء واضحة جداً)
'streets-v12'
```

---

## 📊 مقارنة الأنماط:

### 1. **Streets** (المُستخدم الآن) ⭐⭐⭐⭐⭐

```dart
urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken'
```

**المميزات:**
- ✅ أسماء المدن **واضحة جداً**
- ✅ أسماء القرى **الصغيرة جداً** تظهر
- ✅ أسماء الشوارع **بالتفصيل**
- ✅ أسماء المحلات والأماكن
- ✅ أيقونات للمحلات والخدمات
- ✅ ألوان واضحة ومريحة للعين

**السلبيات:**
- ❌ ليس صور ستلايت (خريطة رسومية)

**أفضل لـ:**
- عرض الأسماء والتفاصيل
- التنقل والبحث
- رؤية جميع الأماكن

---

### 2. **Satellite Streets** (القديم)

```dart
urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken'
```

**المميزات:**
- ✅ صور ستلايت واقعية
- ✅ يعرض المعالم الطبيعية
- ⚠️ أسماء المدن الكبيرة فقط

**السلبيات:**
- ❌ أسماء القرى الصغيرة **غير واضحة**
- ❌ أسماء المحلات **لا تظهر**
- ❌ يحتاج zoom عالي جداً لرؤية التفاصيل

**أفضل لـ:**
- رؤية المناظر الطبيعية
- المناطق الريفية
- التخطيط العمراني

---

### 3. **Outdoors** (للطبيعة)

```dart
urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken'
```

**المميزات:**
- ✅ تضاريس واضحة
- ✅ مسارات المشي
- ✅ أسماء جيدة

**السلبيات:**
- ⚠️ مصمم للمناطق الطبيعية
- ⚠️ ليس الأفضل للمدن

---

### 4. **Light / Dark** (للتصميم)

```dart
// Light
'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxToken'

// Dark
'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxToken'
```

**المميزات:**
- ✅ تصميم بسيط وأنيق
- ✅ ألوان هادئة

**السلبيات:**
- ❌ تفاصيل أقل من Streets
- ❌ أسماء أقل

---

## 🎯 التوصية حسب الاستخدام:

| الاستخدام | النمط الأفضل |
|-----------|--------------|
| **عرض جميع الأسماء** (قرى، محلات) | **Streets** ⭐ |
| صور ستلايت واقعية | Satellite Streets |
| المناطق الطبيعية والتضاريس | Outdoors |
| تصميم أنيق بسيط | Light / Dark |

---

## 🔄 كيفية التبديل بين الأنماط:

### في الكود الحالي:

**افتح:**
```
lib/features/clinics/presentation/screens/clinics_map_screen.dart
```

**ابحث عن السطر:**
```dart
urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=$_mapboxToken',
```

**استبدل `streets-v12` بأي نمط:**
- `satellite-streets-v12` → صور ستلايت + أسماء
- `streets-v12` → خريطة عادية (الأفضل للأسماء) ⭐
- `outdoors-v12` → طبيعة وتضاريس
- `light-v11` → فاتح
- `dark-v11` → غامق

---

## 💡 نصيحة:

### للحصول على أفضل تجربة:

**استخدم Streets للاستخدام اليومي:**
- ✅ كل الأسماء واضحة
- ✅ سهل القراءة
- ✅ سريع في التحميل

**استخدم Satellite Streets للعروض التقديمية:**
- ✅ منظر جميل
- ✅ واقعي أكثر

---

## 🧪 إضافة زر للتبديل (اختياري):

```dart
// في أول الملف
enum MapStyle { streets, satellite, outdoors }

class _ClinicsMapScreenState extends ConsumerState<ClinicsMapScreen> {
  MapStyle _currentStyle = MapStyle.streets;
  
  String _getMapboxStyleUrl() {
    final baseUrl = 'https://api.mapbox.com/styles/v1/mapbox/';
    final style = switch (_currentStyle) {
      MapStyle.streets => 'streets-v12',
      MapStyle.satellite => 'satellite-streets-v12',
      MapStyle.outdoors => 'outdoors-v12',
    };
    return '$baseUrl$style/tiles/{z}/{x}/{y}?access_token=$_mapboxToken';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          // زر تغيير النمط
          PopupMenuButton<MapStyle>(
            icon: const Icon(Icons.layers),
            initialValue: _currentStyle,
            onSelected: (style) => setState(() => _currentStyle = style),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: MapStyle.streets,
                child: Row(
                  children: [
                    Icon(Icons.map),
                    SizedBox(width: 8),
                    Text('خريطة عادية (أوضح)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: MapStyle.satellite,
                child: Row(
                  children: [
                    Icon(Icons.satellite),
                    SizedBox(width: 8),
                    Text('ستلايت'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: MapStyle.outdoors,
                child: Row(
                  children: [
                    Icon(Icons.terrain),
                    SizedBox(width: 8),
                    Text('طبيعة'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: FlutterMap(
        children: [
          TileLayer(
            urlTemplate: _getMapboxStyleUrl(),
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

## ✅ الخلاصة:

**الآن يستخدم Streets** → كل الأسماء واضحة! ✨

إذا أردت العودة لـ Satellite، استبدل:
```dart
'streets-v12' → 'satellite-streets-v12'
```

لكن Streets أفضل لعرض أسماء القرى والمحلات! 🗺️
