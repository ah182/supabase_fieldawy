# 🎯 Top Users حسب عدد المنتجات (Distributor Products + Distributor OCR)

## ✅ التحديث المطبق

تم تحديث `getTopUsersByActivity()` ليرتب الموزعين حسب **إجمالي عدد المنتجات** (Distributor Products + Distributor OCR).

---

## 🔄 التغيير

### قبل التحديث:
```dart
// كان يرتب حسب عدد البحث والمشاهدات
var sortedUsers = userStats.entries.toList()
  ..sort((a, b) {
    final activityA = (a.value['total_searches'] as int) + (a.value['total_views'] as int);
    final activityB = (b.value['total_searches'] as int) + (b.value['total_views'] as int);
    return activityB.compareTo(activityA);
  });
```

**المشكلة:**
- الترتيب كان حسب البحث والمشاهدات فقط ❌
- لم يعرض عدد المنتجات اللي أضافها المستخدم

---

### بعد التحديث:
```dart
// 1. جلب منتجات الموزعين (من جدول distributor_products)
final distributorProductsData = await supabase
    .from('distributor_products')
    .select('distributor_id');

// 2. جلب منتجات OCR الموزعين (من جدول distributor_ocr_products)
final distributorOcrData = await supabase
    .from('distributor_ocr_products')
    .select('distributor_id');

// 3. حساب إجمالي المنتجات لكل مستخدم
for (var userId in userStats.keys) {
  final catalogCount = userStats[userId]['catalog_products'];
  final ocrCount = userStats[userId]['ocr_products'];
  userStats[userId]['total_products'] = catalogCount + ocrCount;
}

// 4. ترتيب حسب إجمالي عدد المنتجات (الأعلى أولاً)
var sortedUsers = userStats.entries.toList()
  ..sort((a, b) {
    final productsA = a.value['total_products'] as int;
    final productsB = b.value['total_products'] as int;
    return productsB.compareTo(productsA); // من الأعلى للأقل
  });
```

**الحل:**
- ✅ يحسب عدد منتجات Catalog (من `products.distributor_id`)
- ✅ يحسب عدد منتجات OCR (من `ocr_products.user_id`)
- ✅ يجمع العددين مع بعض
- ✅ يرتب حسب الإجمالي من الأعلى للأقل

---

## 📊 كيف يعمل الآن

### مثال:

#### البيانات:
```
User A: 150 منتج Catalog + 50 منتج OCR = 200 منتج إجمالي
User B: 120 منتج Catalog + 30 منتج OCR = 150 منتج إجمالي
User C: 80 منتج Catalog + 100 منتج OCR = 180 منتج إجمالي
```

#### النتيجة في Top Users:
```
1. User A - 200 منتج (150 Catalog + 50 OCR) ⭐
2. User C - 180 منتج (80 Catalog + 100 OCR)
3. User B - 150 منتج (120 Catalog + 30 OCR)
```

**الترتيب حسب إجمالي المنتجات (Catalog + OCR)** ✅

---

## 🎯 الميزات

### 1. حساب شامل:
- ✅ منتجات **Catalog** (جدول `products`)
- ✅ منتجات **OCR** (جدول `ocr_products`)
- ✅ الإجمالي = Catalog + OCR

### 2. ترتيب صحيح:
- ✅ المستخدم صاحب أكثر منتجات يظهر أولاً
- ✅ يشمل كل أنواع المنتجات

### 3. معلومات إضافية:
- ✅ إجمالي المنتجات
- ✅ عدد البحث (اختياري)
- ✅ عدد المشاهدات (اختياري)

---

## 📋 التفاصيل التقنية

### الخطوات:

#### 1. جلب منتجات Catalog:
```dart
final catalogResponse = await supabase
    .from('products')
    .select('distributor_id');

// عدّ لكل مستخدم
for (var product in catalogData) {
  final userId = product['distributor_id'];
  userStats[userId]['catalog_products']++;
}
```

#### 2. جلب منتجات OCR:
```dart
final ocrResponse = await supabase
    .from('ocr_products')
    .select('user_id');

// عدّ لكل مستخدم
for (var product in ocrData) {
  final userId = product['user_id'];
  userStats[userId]['ocr_products']++;
}
```

#### 3. حساب الإجمالي:
```dart
for (var userId in userStats.keys) {
  final catalogCount = userStats[userId]['catalog_products'];
  final ocrCount = userStats[userId]['ocr_products'];
  userStats[userId]['total_products'] = catalogCount + ocrCount;
}
```

#### 4. الترتيب:
```dart
var sortedUsers = userStats.entries.toList()
  ..sort((a, b) {
    final productsA = a.value['total_products'];
    final productsB = b.value['total_products'];
    return productsB.compareTo(productsA); // من الأعلى للأقل
  });
```

#### 5. جلب بيانات المستخدمين:
```dart
final usersData = await supabase
    .from('users')
    .select('id, full_name, email, role')
    .inFilter('id', topUserIds);
```

#### 6. النتيجة:
```dart
return results; // مرتب حسب عدد المنتجات
```

---

## 🧪 الاختبار

### 1. شغّل التطبيق:
```bash
flutter run -d chrome
```

### 2. افتح Analytics → Top Performers:
- تاب **Top Users**

### 3. تحقق من:
- ✅ المستخدم صاحب أكثر منتجات في الأول
- ✅ الترتيب تنازلي حسب عدد المنتجات
- ✅ العدد الإجمالي صحيح (Catalog + OCR)

---

## 📊 مثال العرض

```
┌───────────────────────────────────────────────────────────────┐
│ Top Users by Products Count                                   │
├───────────────────────────────────────────────────────────────┤
│ Rank │ User Name      │ Email           │ Total Products │ Role│
├──────┼────────────────┼─────────────────┼────────────────┼─────┤
│  1   │ Ahmed Hassan   │ ahmed@email.com │ 250 ⭐         │ Dist│
│  2   │ Mohamed Ali    │ mohamed@mail.com│ 180            │ Dist│
│  3   │ Sara Ibrahim   │ sara@email.com  │ 150            │ Dist│
│  4   │ Fatma Khaled   │ fatma@mail.com  │ 120            │ Dist│
│  5   │ Omar Saeed     │ omar@email.com  │ 95             │ Dist│
└──────┴────────────────┴─────────────────┴────────────────┴─────┘
```

**الترتيب من الأعلى للأقل حسب Total Products (Catalog + OCR)** ✅

---

## 📝 ملاحظات مهمة

### 1. الجداول المستخدمة:
- ✅ `products` - منتجات Catalog (عمود `distributor_id`)
- ✅ `ocr_products` - منتجات OCR (عمود `user_id`)
- ✅ `users` - بيانات المستخدمين
- ⚠️ `search_tracking` - اختياري (للبحث)
- ⚠️ `product_views` - اختياري (للمشاهدات)

### 2. الأعمدة المطلوبة:
**في جدول `products`:**
- `distributor_id` - معرف الموزع (صاحب المنتج)

**في جدول `ocr_products`:**
- `user_id` - معرف المستخدم (صاحب المنتج)

**في جدول `users`:**
- `id`, `full_name`, `email`, `role`

### 3. البحث والمشاهدات:
- يتم جلبهم بشكل **اختياري**
- إذا فشل الجلب، الترتيب يبقى حسب عدد المنتجات فقط
- يظهروا في الـ UI لكن مش أساسيين للترتيب

---

## ⚠️ إذا كانت الأعمدة مختلفة

### إذا كان جدول `products` يستخدم عمود مختلف:
```dart
// بدلاً من distributor_id
final catalogResponse = await supabase
    .from('products')
    .select('user_id'); // أو seller_id أو أي عمود تاني
```

### إذا كان جدول `ocr_products` يستخدم عمود مختلف:
```dart
// بدلاً من user_id
final ocrResponse = await supabase
    .from('ocr_products')
    .select('distributor_id'); // أو أي عمود تاني
```

---

## ✅ الخلاصة

### قبل:
- ❌ ترتيب حسب البحث والمشاهدات فقط
- ❌ لا يعرض عدد المنتجات

### بعد:
- ✅ ترتيب حسب عدد المنتجات (Catalog + OCR)
- ✅ المستخدم صاحب أكثر منتجات يظهر أولاً
- ✅ يجمع منتجات من جدولين (`products` + `ocr_products`)
- ✅ إجمالي دقيق = Catalog + OCR

---

**🎊 الآن Top Users يعرض المستخدمين حسب عدد المنتجات بشكل صحيح! 🎊**

```bash
flutter run -d chrome
```

**ثم اختبر Analytics → Top Performers → Top Users**

---

## 🔍 معلومة إضافية

### الفرق بين Catalog و OCR:

**منتجات Catalog:**
- يضيفها الموزع عن طريق الـ Admin Dashboard
- تُحفظ في جدول `products`
- العمود المستخدم: `distributor_id`

**منتجات OCR:**
- يضيفها المستخدم عن طريق تصوير الروشتة (OCR)
- تُحفظ في جدول `ocr_products`
- العمود المستخدم: `user_id`

**الإجمالي = Catalog + OCR** ✅
