# إصلاح مشكلة Type Casting

## المشكلة
```
type '_Map<dynamic, dynamic>' is not a subtype of type 'Map<String, dynamic>' in type cast
```

## السبب
كان الكود يستخدم:
```dart
json as Map<String, dynamic>
```

لكن عندما يُخزن JSON في Hive ويُقرأ منه، يعيده كـ `Map<dynamic, dynamic>` وليس `Map<String, dynamic>`، مما يسبب فشل الـ type cast.

## الحل
استخدام `Map<String, dynamic>.from(json)` بدلاً من `json as Map<String, dynamic>`

### قبل الإصلاح:
```dart
fromCache: (data) {
  final List<dynamic> jsonList = data as List<dynamic>;
  return jsonList.map((json) => Book.fromJson(json as Map<String, dynamic>)).toList();
}
```

### بعد الإصلاح:
```dart
fromCache: (data) {
  final List<dynamic> jsonList = data as List<dynamic>;
  return jsonList.map((json) => Book.fromJson(Map<String, dynamic>.from(json))).toList();
}
```

## الفرق بين `as` و `.from()`

### `as` Type Cast
- يفشل إذا كان النوع الفعلي لا يطابق تماماً
- `Map<dynamic, dynamic> as Map<String, dynamic>` ❌ يفشل

### `.from()` Constructor
- ينشئ نسخة جديدة من النوع الصحيح
- `Map<String, dynamic>.from(Map<dynamic, dynamic>)` ✅ ينجح

## الملفات المُصلحة

### 1. BooksRepository
- ✅ `getAllBooks()` - استخدام `.from()` في fromCache
- ✅ `getMyBooks()` - استخدام `.from()` في fromCache

### 2. CoursesRepository
- ✅ `getAllCourses()` - استخدام `.from()` في fromCache
- ✅ `getMyCourses()` - استخدام `.from()` في fromCache

### 3. JobOffersRepository
- ✅ `getAllJobOffers()` - استخدام `.from()` في fromCache
- ✅ `getMyJobOffers()` - استخدام `.from()` في fromCache

### 4. LeaderboardRepository
- ✅ `getLeaderboard()` - استخدام `.from()` في fromCache

### 5. ClinicRepository
- ✅ `getAllClinicsWithDoctorInfo()` - استخدام `.from()` في fromCache

### 6. DashboardRepository
- ✅ `getDashboardStats()` - استخدام `.from()` في fromCache
- ✅ `getRecentProducts()` - استخدام `.map((e) => Map<String, dynamic>.from(e)).toList()`
- ✅ `getTopProducts()` - استخدام `.map((e) => Map<String, dynamic>.from(e)).toList()`
- ✅ `getGlobalTopProductsNotOwned()` - استخدام `.map((e) => Map<String, dynamic>.from(e)).toList()`
- ✅ `getExpiringProducts()` - استخدام `.map((e) => Map<String, dynamic>.from(e)).toList()`
- ✅ `getMonthlySalesData()` - استخدام `.map((e) => Map<String, dynamic>.from(e)).toList()`
- ✅ `getRegionalStats()` - استخدام `.map((e) => Map<String, dynamic>.from(e)).toList()`

## ملاحظة مهمة
استخدمنا طريقتين مختلفتين بناءً على نوع البيانات:

### للكائنات (Models):
```dart
Book.fromJson(Map<String, dynamic>.from(json))
```

### لـ List<Map<String, dynamic>> مباشرة:
```dart
(data as List<dynamic>).map((e) => Map<String, dynamic>.from(e)).toList()
```

## النتيجة
- ✅ لا مزيد من أخطاء Type Casting
- ✅ جميع الـ repositories تعمل بشكل صحيح
- ✅ الكاش يعمل بدون مشاكل
- ✅ التطبيق يعمل بشكل طبيعي
