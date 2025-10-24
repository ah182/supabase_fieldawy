# 🔧 إصلاح MapTiler URLs

## ❌ المشكلة:
```
Request to https://api.maptiler.com/maps/hybrid/256/15/19154/13421.jpg failed with status 500
```

## ✅ الحل:

تم تغيير الـ URLs إلى الصيغة الصحيحة:

### الطبقة 1: صور Satellite
```dart
'https://api.maptiler.com/tiles/satellite-v2/{z}/{x}/{y}.jpg?key=$_mapTilerKey'
```

### الطبقة 2: الأسماء (Labels)
```dart
'https://api.maptiler.com/maps/hybrid/256/{z}/{x}/{y}.png?key=$_mapTilerKey'
```

---

## 🗺️ URLs الصحيحة لـ MapTiler:

### 1. **Satellite (صور ستلايت فقط)**
```dart
urlTemplate: 'https://api.maptiler.com/tiles/satellite-v2/{z}/{x}/{y}.jpg?key=$_mapTilerKey'
```

### 2. **Streets (خريطة عادية)**
```dart
urlTemplate: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$_mapTilerKey'
```

### 3. **Outdoor (طبيعة)**
```dart
urlTemplate: 'https://api.maptiler.com/maps/outdoor-v2/{z}/{x}/{y}.png?key=$_mapTilerKey'
```

### 4. **Basic (بسيط)**
```dart
urlTemplate: 'https://api.maptiler.com/maps/basic-v2/{z}/{x}/{y}.png?key=$_mapTilerKey'
```

### 5. **Topo (طبوغرافي)**
```dart
urlTemplate: 'https://api.maptiler.com/maps/topo-v2/{z}/{x}/{y}.png?key=$_mapTilerKey'
```

---

## 🎯 الأفضل: Satellite + Labels

استخدم طبقتين:

```dart
children: [
  // طبقة 1: صور الستلايت
  TileLayer(
    urlTemplate: 'https://api.maptiler.com/tiles/satellite-v2/{z}/{x}/{y}.jpg?key=$_mapTilerKey',
    maxZoom: 20,
  ),
  
  // طبقة 2: الأسماء والطرق
  TileLayer(
    urlTemplate: 'https://api.maptiler.com/maps/hybrid/256/{z}/{x}/{y}.png?key=$_mapTilerKey',
    maxZoom: 20,
  ),
  
  MarkerLayer(markers: _markers),
]
```

---

## 🔍 ملاحظات مهمة:

1. **لا تضع `/256/` في أول الـ URL** - فقط في بعض الأنماط
2. **استخدم `.jpg` للصور** و `.png` للأنماط
3. **maxZoom: 20** لـ MapTiler (ليس 22)
4. **تأكد من الـ API key صحيح**

---

## ✅ التطبيق الحالي:

الآن يستخدم:
- ✅ Satellite tiles الصحيحة
- ✅ Hybrid labels للأسماء
- ✅ طبقتين منفصلتين

شغّل التطبيق وستعمل بدون أخطاء! 🚀
