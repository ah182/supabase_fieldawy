# 🛰️ إعداد خريطة بمنظر ستلايت مع أسماء المدن

## ✅ تم التطبيق:

### النظام المستخدم:
**ESRI World Imagery + Labels** (مجاني بدون API key)

```dart
children: [
  // طبقة 1: صور الأقمار الصناعية
  TileLayer(
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    maxZoom: 19,
    tileProvider: NetworkTileProvider(),
  ),
  
  // طبقة 2: أسماء المدن والقرى
  TileLayer(
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    maxZoom: 19,
    tileProvider: NetworkTileProvider(),
  ),
  
  // طبقة 3: العيادات والماركرز
  MarkerLayer(markers: _markers),
]
```

---

## 🌟 المميزات:

- ✅ **صور واقعية** من الأقمار الصناعية
- ✅ **أسماء المدن والقرى** بالعربي والإنجليزي
- ✅ **معالم واضحة** (مباني، طرق، أنهار)
- ✅ **مجاني 100%** - لا يحتاج API key
- ✅ **سريع** - من ESRI servers

---

## 🎨 بدائل أخرى (حسب الرغبة):

### 1. Google Maps Style (يحتاج API key)
```dart
TileLayer(
  urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
  // lyrs=s  → satellite
  // lyrs=y  → satellite + labels (hybrid)
  // lyrs=m  → normal map
  maxZoom: 20,
)
```

⚠️ **ملاحظة:** استخدام Google tiles بدون API key قد يُحجب

---

### 2. Mapbox Satellite (يحتاج token مجاني)
```dart
TileLayer(
  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v11/tiles/{z}/{x}/{y}?access_token=YOUR_TOKEN',
  maxZoom: 22,
)
```

للحصول على token مجاني:
1. اذهب لـ https://www.mapbox.com/signup
2. أنشئ حساب
3. انسخ الـ access token

---

### 3. ESRI Variants (مجانية):

#### A. Satellite فقط (بدون أسماء):
```dart
TileLayer(
  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
)
```

#### B. Hybrid (satellite + roads + labels):
```dart
// الطبقة الأولى: Satellite
TileLayer(
  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
),
// الطبقة الثانية: Transportation (طرق)
TileLayer(
  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
),
// الطبقة الثالثة: Labels (أسماء)
TileLayer(
  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
),
```

#### C. شوارع فقط (مثل Google Streets):
```dart
TileLayer(
  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
)
```

---

## 🔄 تبديل بين الأنماط في التطبيق

يمكنك إضافة زر لتغيير نمط الخريطة:

```dart
enum MapStyle { satellite, street, hybrid }

class _ClinicsMapScreenState extends ConsumerState<ClinicsMapScreen> {
  MapStyle _mapStyle = MapStyle.satellite;
  
  List<Widget> _getTileLayers() {
    switch (_mapStyle) {
      case MapStyle.satellite:
        return [
          TileLayer(urlTemplate: '...satellite...'),
          TileLayer(urlTemplate: '...labels...'),
        ];
      case MapStyle.street:
        return [
          TileLayer(urlTemplate: '...streets...'),
        ];
      case MapStyle.hybrid:
        return [
          TileLayer(urlTemplate: '...satellite...'),
          TileLayer(urlTemplate: '...roads...'),
          TileLayer(urlTemplate: '...labels...'),
        ];
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.layers),
            onPressed: () {
              setState(() {
                _mapStyle = MapStyle.values[
                  (_mapStyle.index + 1) % MapStyle.values.length
                ];
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

## 🚀 الخطوة التالية:

```bash
flutter run
```

افتح خريطة العيادات → يجب أن ترى:
- ✅ صور الأقمار الصناعية
- ✅ أسماء المدن والقرى
- ✅ العيادات (ماركر أحمر)
- ✅ موقعك (ماركر أزرق)

---

## 🐛 إذا لم تظهر الصور:

1. **تحقق من الإنترنت** في المحاكي/الجهاز
2. **أعد تشغيل التطبيق:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **تحقق من console للأخطاء:**
   ```bash
   flutter run -v | grep -i "tile\|error"
   ```

---

## 📊 مقارنة بين الخيارات:

| Provider | Satellite | Labels | مجاني | API Key | جودة |
|----------|-----------|--------|-------|---------|------|
| **ESRI** (الحالي) | ✅ | ✅ | ✅ | ❌ | ⭐⭐⭐⭐ |
| Google Maps | ✅ | ✅ | ⚠️ | ✅ | ⭐⭐⭐⭐⭐ |
| Mapbox | ✅ | ✅ | ✅ | ✅ (مجاني) | ⭐⭐⭐⭐⭐ |
| OSM | ❌ | ✅ | ✅ | ❌ | ⭐⭐⭐ |

---

## ✅ التوصية:

**للاستخدام الحالي:** ESRI (تم تطبيقه) - مجاني وممتاز

**للمستقبل:** إذا أردت أفضل جودة:
1. أنشئ حساب Mapbox مجاني
2. استخدم Mapbox Satellite Streets
3. جودة أعلى + تحديثات أسرع

---

**جرّب التطبيق الآن!** يجب أن ترى منظر ستلايت مع أسماء المدن 🛰️🗺️
