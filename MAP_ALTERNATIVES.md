# 🗺️ بدائل خرائط أخرى (إذا لم تظهر الأسماء)

## الحل الحالي المُطبّق:
✅ ESRI World Imagery + Transportation + Labels + زوم حتى 22

---

## 🚀 بديل 1: Google Hybrid (الأفضل - مثل Google Maps تماماً)

```dart
children: [
  // Google Satellite + Labels (Hybrid)
  TileLayer(
    urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
    userAgentPackageName: 'com.fieldawy.store',
    maxZoom: 22,
    tileProvider: NetworkTileProvider(),
  ),
  MarkerLayer(markers: _markers),
]
```

### رموز Google Maps:
- `lyrs=y` → Hybrid (satellite + labels) ⭐ **الأفضل**
- `lyrs=s` → Satellite فقط
- `lyrs=m` → Normal map
- `lyrs=p` → Terrain
- `lyrs=h` → Roads only

⚠️ **ملاحظة:** Google قد تحجب الاستخدام بدون API key لاحقاً

---

## 🌟 بديل 2: Mapbox Satellite Streets (ممتاز + مجاني)

### الخطوات:
1. **إنشاء حساب مجاني:**
   - اذهب لـ: https://account.mapbox.com/auth/signup/
   - سجّل حساب (مجاني - 50,000 طلب شهرياً)

2. **احصل على Token:**
   - بعد التسجيل: https://account.mapbox.com/access-tokens/
   - انسخ الـ **Default public token**

3. **استخدمه في الكود:**

```dart
children: [
  // Mapbox Satellite Streets
  TileLayer(
    urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/{z}/{x}/{y}?access_token=YOUR_TOKEN_HERE',
    userAgentPackageName: 'com.fieldawy.store',
    maxZoom: 22,
    tileProvider: NetworkTileProvider(),
  ),
  MarkerLayer(markers: _markers),
]
```

استبدل `YOUR_TOKEN_HERE` بالـ token الخاص بك

### أنماط Mapbox المتاحة:
- `satellite-streets-v12` → Satellite + roads + labels ⭐
- `satellite-v9` → Satellite فقط
- `streets-v12` → Normal streets
- `outdoors-v12` → Outdoor/hiking
- `dark-v11` → Dark mode
- `light-v11` → Light mode

---

## 🎯 بديل 3: ESRI كامل (مجاني - لكن أبطأ قليلاً)

**الكود الحالي** + إضافة طبقة إضافية:

```dart
children: [
  // 1. Satellite
  TileLayer(
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    maxZoom: 22,
  ),
  // 2. Transportation
  TileLayer(
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
    maxZoom: 22,
  ),
  // 3. Boundaries & Places
  TileLayer(
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    maxZoom: 22,
  ),
  // 4. أسماء إضافية (اختياري)
  TileLayer(
    urlTemplate: 'https://services.arcgisonline.com/arcgis/rest/services/Reference/World_Reference_Overlay/MapServer/tile/{z}/{y}/{x}',
    maxZoom: 22,
  ),
  MarkerLayer(markers: _markers),
]
```

---

## 🔥 بديل 4: Stadia Maps (جميل جداً)

```dart
TileLayer(
  urlTemplate: 'https://tiles.stadiamaps.com/tiles/alidade_satellite/{z}/{x}/{y}.jpg',
  maxZoom: 20,
)
```

⚠️ يحتاج API key مجاني: https://client.stadiamaps.com/signup/

---

## 🏆 التوصية النهائية:

### للاستخدام الفوري (بدون تسجيل):
✅ **Google Hybrid** - الأفضل والأسرع

```dart
TileLayer(
  urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
  maxZoom: 22,
)
```

### للاستخدام طويل الأمد (مستقر):
✅ **Mapbox** - احترافي + مجاني حتى 50k request/month

---

## 🧪 كيفية التجربة:

1. **افتح الملف:**
   ```
   lib/features/clinics/presentation/screens/clinics_map_screen.dart
   ```

2. **استبدل الـ children داخل FlutterMap بـ:**

   ```dart
   children: [
     TileLayer(
       urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
       maxZoom: 22,
     ),
     MarkerLayer(markers: _markers),
     // ... باقي الـ widgets
   ]
   ```

3. **احفظ وشغّل:**
   ```bash
   flutter run
   ```

---

## 🔍 مقارنة الأداء:

| Provider | السرعة | الوضوح | الأسماء | مجاني | API Key |
|----------|--------|--------|---------|-------|---------|
| **Google Hybrid** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⚠️ | ❌ |
| **Mapbox** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ | ✅ (مجاني) |
| **ESRI** (الحالي) | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ | ❌ |
| **OpenStreetMap** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ | ❌ |

---

## 📱 نصائح إضافية:

### 1. زيادة وضوح الأسماء:
أضف هذا للـ MapOptions:

```dart
options: MapOptions(
  initialCenter: _initialPosition,
  initialZoom: 12,  // ✅ ابدأ بزوم أعلى
  minZoom: 5,
  maxZoom: 22,
  interactionOptions: const InteractionOptions(
    flags: InteractiveFlag.all,
  ),
),
```

### 2. تحسين الأداء:
```dart
TileLayer(
  urlTemplate: '...',
  maxZoom: 22,
  tileProvider: NetworkTileProvider(),
  keepBuffer: 3,  // يحتفظ بـ tiles أكثر في الذاكرة
  panBuffer: 1,   // تحميل مسبق أثناء التحريك
),
```

### 3. التحقق من تحميل الصور:
أضف error handler:

```dart
TileLayer(
  urlTemplate: '...',
  errorTileCallback: (tile, error, stackTrace) {
    print('❌ Error loading tile: $error');
  },
),
```

---

**جرّب Google Hybrid أولاً - إذا اشتغل معك، خلّيه! 🚀**
