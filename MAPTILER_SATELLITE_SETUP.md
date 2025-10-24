# 🛰️ MapTiler Satellite مع الأسماء

## ✅ التطبيق الحالي:

الآن يستخدم **طبقتين**:

### الطبقة 1: صور الستلايت
```dart
TileLayer(
  urlTemplate: 'https://api.maptiler.com/tiles/satellite-v2/{z}/{x}/{y}.jpg?key=$_mapTilerKey',
  maxZoom: 20,
)
```

### الطبقة 2: الأسماء (Overlay)
```dart
TileLayer(
  urlTemplate: 'https://api.maptiler.com/maps/hybrid/{z}/{x}/{y}@2x.png?key=$_mapTilerKey',
  maxZoom: 20,
)
```

---

## 🎯 النتيجة:

**ستحصل على:**
- 🛰️ صور ستلايت واضحة (من satellite-v2)
- 🏙️ أسماء المدن والقرى (من hybrid overlay)
- 🛣️ أسماء الشوارع
- 🏪 المحلات والأماكن (عند zoom عالي)

---

## 🔧 بدائل أخرى:

### 1. Satellite بدون أسماء (صور فقط):

استخدم طبقة واحدة:
```dart
children: [
  TileLayer(
    urlTemplate: 'https://api.maptiler.com/tiles/satellite-v2/{z}/{x}/{y}.jpg?key=$_mapTilerKey',
    maxZoom: 20,
  ),
  MarkerLayer(markers: _markers),
]
```

---

### 2. Satellite + أسماء أوضح:

استخدم overlay مختلف:
```dart
children: [
  // Satellite
  TileLayer(
    urlTemplate: 'https://api.maptiler.com/tiles/satellite-v2/{z}/{x}/{y}.jpg?key=$_mapTilerKey',
    maxZoom: 20,
  ),
  // Labels Overlay (أوضح)
  TileLayer(
    urlTemplate: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$_mapTilerKey',
    maxZoom: 20,
    // اجعلها شبه شفافة للرؤية الأفضل
  ),
  MarkerLayer(markers: _markers),
]
```

---

### 3. جودة أعلى (@2x):

استخدم tiles بدقة أعلى:
```dart
// Satellite بدقة عالية
urlTemplate: 'https://api.maptiler.com/tiles/satellite-v2/{z}/{x}/{y}@2x.jpg?key=$_mapTilerKey'

// Labels بدقة عالية
urlTemplate: 'https://api.maptiler.com/maps/hybrid/{z}/{x}/{y}@2x.png?key=$_mapTilerKey'
```

⚠️ **تحميل أبطأ** لكن جودة أفضل

---

## 📊 مقارنة الطبقات:

| Overlay | الأسماء | الوضوح | الحجم |
|---------|--------|--------|-------|
| **hybrid overlay** (الحالي) | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | خفيف |
| streets-v2 overlay | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | متوسط |
| @2x variants | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ثقيل |

---

## 💡 نصائح:

### لتحسين الأداء:
```dart
TileLayer(
  urlTemplate: '...',
  maxZoom: 20,
  tileProvider: NetworkTileProvider(),
  keepBuffer: 2,  // احتفظ بـ tiles أقل
  panBuffer: 0,   // لا تحمل tiles إضافية
)
```

### لتحسين الوضوح:
```dart
TileLayer(
  urlTemplate: '...@2x.jpg?key=$_mapTilerKey',
  maxZoom: 20,
  tileSize: 512,  // حجم أكبر = جودة أعلى
)
```

---

## 🎨 تبديل بين Satellite و Streets:

```dart
enum MapMode { satellite, streets }

class _ClinicsMapScreenState extends ConsumerState<ClinicsMapScreen> {
  MapMode _mapMode = MapMode.satellite;
  
  List<Widget> _getTileLayers() {
    if (_mapMode == MapMode.satellite) {
      return [
        TileLayer(
          urlTemplate: 'https://api.maptiler.com/tiles/satellite-v2/{z}/{x}/{y}.jpg?key=$_mapTilerKey',
          maxZoom: 20,
        ),
        TileLayer(
          urlTemplate: 'https://api.maptiler.com/maps/hybrid/{z}/{x}/{y}@2x.png?key=$_mapTilerKey',
          maxZoom: 20,
        ),
      ];
    } else {
      return [
        TileLayer(
          urlTemplate: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$_mapTilerKey',
          maxZoom: 20,
        ),
      ];
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(_mapMode == MapMode.satellite ? Icons.map : Icons.satellite),
            onPressed: () {
              setState(() {
                _mapMode = _mapMode == MapMode.satellite 
                    ? MapMode.streets 
                    : MapMode.satellite;
              });
            },
          ),
        ],
      ),
      body: FlutterMap(
        children: [
          ..._getTileLayers(),
          MarkerLayer(markers: _markers),
        ],
      ),
    );
  }
}
```

---

## ✅ الوضع الحالي:

- ✅ صور ستلايت من MapTiler
- ✅ أسماء واضحة (overlay)
- ✅ URLs صحيحة
- ✅ maxZoom: 20 (أقصى ما يدعمه MapTiler)

---

## 🐛 إذا لم تظهر الأسماء:

جرّب overlay مختلف:
```dart
// بدلاً من hybrid، استخدم streets overlay:
urlTemplate: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$_mapTilerKey'
```

أو اجعل zoom أعلى (15-18) لرؤية الأسماء بوضوح.

---

**شغّل التطبيق الآن - ستلايت مع الأسماء!** 🛰️✨
