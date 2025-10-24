# 🗺️ مقدمي الخرائط المجانية والقانونية

## ✅ الحل المُطبّق: ESRI (قانوني 100%)

### الطبقات المستخدمة:
```dart
// 1. صور الأقمار الصناعية
TileLayer(
  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  maxZoom: 20,
)

// 2. الطرق والمواصلات
TileLayer(
  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
  maxZoom: 20,
)

// 3. الحدود والأماكن
TileLayer(
  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
  maxZoom: 20,
)
```

---

## ✅ مقدمي الخرائط القانونيين والمجانيين

### 1. **ESRI ArcGIS** (المستخدم حالياً) ⭐

**الترخيص:** مجاني للاستخدام مع attribution
**الحد:** لا يوجد حد محدد للطلبات
**الجودة:** ⭐⭐⭐⭐
**التفاصيل:** ⭐⭐⭐⭐

#### الخدمات المتاحة:
```dart
// Satellite
'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'

// Streets
'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}'

// Transportation
'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}'

// Boundaries & Places
'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}'

// Topographic
'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}'

// Terrain
'https://server.arcgisonline.com/ArcGIS/rest/services/World_Terrain_Base/MapServer/tile/{z}/{y}/{x}'

// Ocean
'https://server.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}'

// Physical Map
'https://server.arcgisonline.com/ArcGIS/rest/services/World_Physical_Map/MapServer/tile/{z}/{y}/{x}'

// Shaded Relief
'https://server.arcgisonline.com/ArcGIS/rest/services/World_Shaded_Relief/MapServer/tile/{z}/{y}/{x}'
```

**الشروط:**
- ✅ مجاني للاستخدام
- ✅ لا يحتاج API key
- ✅ يتطلب attribution (© Esri)
- ✅ مسموح للاستخدام التجاري

---

### 2. **OpenStreetMap** ⭐⭐⭐⭐⭐

**الترخيص:** Open Data Commons Open Database License (ODbL)
**الحد:** Fair usage policy
**الجودة:** ⭐⭐⭐⭐
**التفاصيل:** ⭐⭐⭐⭐⭐

```dart
// Standard
TileLayer(
  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
  subdomains: const ['a', 'b', 'c'],
  maxZoom: 19,
)
```

**الشروط:**
- ✅ مجاني تماماً
- ✅ Open source
- ✅ يتطلب attribution (© OpenStreetMap contributors)
- ⚠️ Fair usage policy (لا تسيء الاستخدام)

---

### 3. **CartoDB / CARTO** ⭐⭐⭐⭐

**الترخيص:** مجاني مع attribution
**الحد:** Fair usage
**الجودة:** ⭐⭐⭐⭐⭐
**التفاصيل:** ⭐⭐⭐⭐

```dart
// Voyager (واضح وجميل)
TileLayer(
  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
  subdomains: const ['a', 'b', 'c', 'd'],
  maxZoom: 20,
)

// Positron (فاتح)
TileLayer(
  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
  subdomains: const ['a', 'b', 'c', 'd'],
  maxZoom: 20,
)

// Dark Matter (غامق)
TileLayer(
  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
  subdomains: const ['a', 'b', 'c', 'd'],
  maxZoom: 20,
)
```

**الشروط:**
- ✅ مجاني للاستخدام
- ✅ لا يحتاج API key
- ✅ يتطلب attribution (© CARTO, © OpenStreetMap)

---

### 4. **Mapbox** (الأفضل - يحتاج token مجاني) ⭐⭐⭐⭐⭐

**الترخيص:** مجاني حتى 50,000 طلب/شهر
**الحد:** 50,000 map loads شهرياً (مجاناً)
**الجودة:** ⭐⭐⭐⭐⭐
**التفاصيل:** ⭐⭐⭐⭐⭐

```dart
// Satellite Streets (الأفضل)
TileLayer(
  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/{z}/{x}/{y}?access_token=YOUR_TOKEN',
  maxZoom: 22,
)

// Streets
TileLayer(
  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=YOUR_TOKEN',
  maxZoom: 22,
)

// Outdoors
TileLayer(
  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/{z}/{x}/{y}?access_token=YOUR_TOKEN',
  maxZoom: 22,
)
```

**كيفية الحصول على Token:**
1. اذهب لـ: https://account.mapbox.com/auth/signup/
2. سجّل حساب مجاني
3. انسخ الـ Default public token
4. استخدمه في الكود

**الشروط:**
- ✅ مجاني حتى 50,000 طلب/شهر
- ✅ جودة ممتازة جداً
- ✅ قانوني 100%
- ✅ يتطلب attribution (© Mapbox, © OpenStreetMap)

---

### 5. **Stadia Maps** (يحتاج API key مجاني)

**الترخيص:** مجاني حتى 200,000 طلب/شهر
**الحد:** 200,000 map views شهرياً (مجاناً)

```dart
TileLayer(
  urlTemplate: 'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png?api_key=YOUR_KEY',
  maxZoom: 20,
)
```

**الحصول على API key:**
https://client.stadiamaps.com/signup/

---

## ❌ مقدمي الخرائط غير القانونيين (تجنبهم!)

### 1. **Google Maps Tiles** ❌
```dart
// ⚠️ غير قانوني!
'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
```

**المشاكل:**
- ❌ يخالف Terms of Service
- ❌ Google قد توقف الوصول في أي وقت
- ❌ قد يتم رفض التطبيق من Google Play
- ❌ مخاطر قانونية

**البديل القانوني:**
- استخدم `google_maps_flutter` package الرسمي (يحتاج API key مدفوع)

---

### 2. **Apple Maps** ❌
غير متاح للاستخدام خارج أنظمة Apple

---

### 3. **Bing Maps بدون API key** ❌
يتطلب API key رسمي

---

## 🏆 التوصيات النهائية:

### للاستخدام الفوري (بدون تسجيل):

**1. ESRI** (الحالي) ⭐⭐⭐⭐
- ✅ مجاني تماماً
- ✅ لا يحتاج تسجيل
- ✅ صور ستلايت
- ✅ قانوني 100%
- ⚠️ التفاصيل متوسطة

**2. CartoDB Voyager** ⭐⭐⭐⭐⭐
- ✅ مجاني تماماً
- ✅ لا يحتاج تسجيل
- ✅ واضح وجميل جداً
- ✅ قانوني 100%
- ❌ لكن ليس satellite (خريطة عادية)

---

### للاستخدام طويل الأمد (موصى به):

**Mapbox Satellite Streets** ⭐⭐⭐⭐⭐
- ✅ مجاني حتى 50k/شهر
- ✅ أفضل جودة
- ✅ تفاصيل كاملة
- ✅ قانوني 100%
- ⚠️ يحتاج تسجيل (مجاني)

**خطوات التطبيق:**
1. سجّل في Mapbox (5 دقائق)
2. احصل على token
3. استبدل الكود:

```dart
TileLayer(
  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/{z}/{x}/{y}?access_token=pk.YOUR_TOKEN_HERE',
  maxZoom: 22,
)
```

---

## 📋 مقارنة شاملة:

| Provider | مجاني | API Key | Satellite | تفاصيل | قانوني | الحد |
|----------|------|---------|-----------|--------|--------|------|
| **ESRI** | ✅ | ❌ | ✅ | ⭐⭐⭐ | ✅ | غير محدد |
| **OSM** | ✅ | ❌ | ❌ | ⭐⭐⭐⭐ | ✅ | Fair use |
| **CartoDB** | ✅ | ❌ | ❌ | ⭐⭐⭐⭐ | ✅ | Fair use |
| **Mapbox** | ✅ | ✅ (مجاني) | ✅ | ⭐⭐⭐⭐⭐ | ✅ | 50k/شهر |
| **Stadia** | ✅ | ✅ (مجاني) | ❌ | ⭐⭐⭐⭐ | ✅ | 200k/شهر |
| **Google Tiles** | ❌ | ❌ | ✅ | ⭐⭐⭐⭐⭐ | ❌ | محظور |

---

## ✅ الخلاصة:

**الآن تستخدم:** ESRI (قانوني 100% ومجاني)

**للتحسين المستقبلي:** سجّل في Mapbox (الأفضل والأقوى)

**لا تستخدم أبداً:** Google Maps tiles مباشرة (غير قانوني!)

---

## 🔧 كيفية التبديل لـ Mapbox (موصى به):

```dart
// 1. سجّل في: https://account.mapbox.com/auth/signup/
// 2. احصل على token
// 3. استبدل الكود:

TileLayer(
  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/{z}/{x}/{y}?access_token=YOUR_TOKEN',
  maxZoom: 22,
  additionalOptions: const {
    'attribution': '© Mapbox © OpenStreetMap',
  },
)
```

**مجاني حتى 50,000 مشاهدة شهرياً - كافي جداً لمعظم التطبيقات!** 🚀
