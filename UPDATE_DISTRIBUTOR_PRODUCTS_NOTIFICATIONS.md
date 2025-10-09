# 🔄 تحديث: دعم Expire Soon و Price Action لجدول distributor_products

## ✅ ما تم إضافته

### 1. **أعمدة جديدة لجدول `distributor_products`**
- `expiration_date` - تاريخ انتهاء الصلاحية
- `old_price` - السعر القديم (يُحفظ تلقائياً عند التحديث)
- `price_updated_at` - تاريخ آخر تحديث للسعر

### 2. **Trigger تلقائي لتتبع تغيير السعر**
- عند تحديث السعر، يُحفظ السعر القديم تلقائياً
- يُسجل تاريخ التحديث

### 3. **Views جديدة**
- `distributor_products_expiring_soon` - المنتجات قرب الانتهاء
- `distributor_products_price_changes` - المنتجات بتغيير سعر

### 4. **Functions مُحدّثة**
- `get_expiring_products()` - تجمع من distributor_products + distributor_ocr_products
- `get_price_changed_products()` - تجمع من الجدولين

---

## 🚀 التطبيق

### خطوة 1: تطبيق Migration الجديد

افتح **Supabase Dashboard > SQL Editor**:

```sql
-- انسخ والصق محتوى:
supabase/migrations/20250120_add_tracking_to_distributor_products.sql

-- اضغط Run ✅
```

هذا سيضيف:
- ✅ الأعمدة الجديدة
- ✅ Trigger لتتبع السعر تلقائياً
- ✅ Views و Functions

---

### خطوة 2: تطبيق Triggers المُحدّثة

افتح **Supabase Dashboard > SQL Editor**:

```sql
-- انسخ والصق محتوى:
supabase/migrations/20250120_add_product_notification_triggers.sql

-- اضغط Run ✅
```

**ملاحظة:** هذا سيستبدل الـ triggers القديمة بالنسخة المُحدّثة التي تدعم `distributor_products`.

---

## 📊 كيف يعمل الآن

### السيناريو 1: إضافة منتج قرب الانتهاء

```sql
INSERT INTO distributor_products (
  id,
  distributor_id,
  product_id,
  package,
  price,
  expiration_date
) VALUES (
  'dist_prod_test_001',
  'your-distributor-uuid',
  (SELECT id FROM products LIMIT 1),
  'Box of 100',
  150.00,
  NOW() + INTERVAL '30 days' -- ينتهي بعد 30 يوم
);
```

**النتيجة المتوقعة:**
- ✅ Trigger يرسل notification
- ✅ Server يكتشف أن expiration_date < 60 يوم
- ✅ يُرسل إشعار: "تم إضافة [Product Name] في قرب الانتهاء"
- ✅ Navigation إلى Tab 2 (Expire Soon)

---

### السيناريو 2: تحديث سعر منتج

```sql
-- أولاً: إضافة منتج
INSERT INTO distributor_products (
  id,
  distributor_id,
  product_id,
  package,
  price
) VALUES (
  'dist_prod_test_002',
  'your-distributor-uuid',
  (SELECT id FROM products LIMIT 1),
  'Box of 50',
  100.00
);

-- ثانياً: تحديث السعر
UPDATE distributor_products
SET price = 120.00
WHERE id = 'dist_prod_test_002';
```

**ما يحدث:**
1. ✅ Trigger `update_distributor_products_price_tracking` يُشتغل
2. ✅ يحفظ `old_price = 100.00` تلقائياً
3. ✅ يحفظ `price_updated_at = NOW()` تلقائياً
4. ✅ Trigger `notify_product_change` يُشتغل
5. ✅ Server يكتشف تغيير السعر (old_price != new_price)
6. ✅ يُرسل إشعار: "تم تحديث [Product Name] في تغيير السعر"
7. ✅ Navigation إلى Tab 1 (Price Action)

---

## 📋 الجداول المدعومة الآن

| الجدول | Expire Soon | Price Action | Home | Surgical | Offers |
|--------|-------------|--------------|------|----------|--------|
| `distributor_products` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `distributor_ocr_products` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `surgical_tools` | ❌ | ❌ | ❌ | ✅ | ❌ |
| `distributor_surgical_tools` | ❌ | ❌ | ❌ | ✅ | ❌ |
| `offers` | ❌ | ❌ | ❌ | ❌ | ✅ |
| `products` | ❌ | ❌ | ✅ | ❌ | ❌ |

---

## 🔍 الاستعلامات المفيدة

### 1. عرض جميع المنتجات قرب الانتهاء (من الجدولين):

```sql
SELECT * FROM get_expiring_products(60);
```

**النتيجة:** منتجات من `distributor_products` و `distributor_ocr_products` معاً!

---

### 2. عرض جميع المنتجات بتغيير سعر:

```sql
SELECT * FROM get_price_changed_products(30);
```

**النتيجة:** منتجات من الجدولين مع النسبة المئوية للتغيير!

---

### 3. عرض المنتجات قرب الانتهاء من `distributor_products` فقط:

```sql
SELECT * FROM distributor_products_expiring_soon;
```

---

### 4. عرض المنتجات بتغيير سعر من `distributor_products` فقط:

```sql
SELECT * FROM distributor_products_price_changes;
```

---

## 🧪 اختبار شامل

### Test 1: منتج قرب الانتهاء

```sql
-- إضافة منتج
INSERT INTO distributor_products (
  id,
  distributor_id,
  product_id,
  distributor_name,
  package,
  price,
  expiration_date
) VALUES (
  'test_expire_001',
  (SELECT uid FROM users WHERE role = 'distributor' LIMIT 1),
  (SELECT id FROM products LIMIT 1),
  'Test Distributor',
  'Box of 100',
  50.00,
  NOW() + INTERVAL '15 days' -- ينتهي بعد 15 يوم فقط
);
```

**توقع:**
- ✅ إشعار: "تم إضافة [Product Name] في قرب الانتهاء"

---

### Test 2: تحديث سعر (أول مرة)

```sql
-- إضافة
INSERT INTO distributor_products (
  id,
  distributor_id,
  product_id,
  distributor_name,
  package,
  price
) VALUES (
  'test_price_001',
  (SELECT uid FROM users WHERE role = 'distributor' LIMIT 1),
  (SELECT id FROM products LIMIT 1),
  'Test Distributor',
  'Box of 50',
  100.00
);

-- تحديث السعر
UPDATE distributor_products
SET price = 150.00
WHERE id = 'test_price_001';

-- التحقق من الحفظ التلقائي
SELECT 
  id, 
  price as new_price, 
  old_price, 
  price_updated_at
FROM distributor_products
WHERE id = 'test_price_001';
```

**توقع:**
- ✅ `old_price = 100.00` (تلقائياً!)
- ✅ `price = 150.00`
- ✅ `price_updated_at = NOW()` (تلقائياً!)
- ✅ إشعار: "تم تحديث [Product Name] في تغيير السعر"

---

### Test 3: تحديث سعر (مرة ثانية)

```sql
-- تحديث السعر مرة أخرى
UPDATE distributor_products
SET price = 180.00
WHERE id = 'test_price_001';

-- التحقق
SELECT 
  id, 
  price as new_price, 
  old_price, 
  price_updated_at
FROM distributor_products
WHERE id = 'test_price_001';
```

**توقع:**
- ✅ `old_price = 150.00` (السعر السابق!)
- ✅ `price = 180.00` (الجديد)
- ✅ `price_updated_at` محدّث
- ✅ إشعار: "تم تحديث [Product Name] في تغيير السعر"

---

## 📱 في التطبيق

### عرض المنتجات قرب الانتهاء:

الآن يمكن تحديث `ExpireDrugsProvider` لاستخدام:

```dart
// في Flutter
final result = await supabase
    .rpc('get_expiring_products', params: {'days_threshold': 60})
    .execute();
```

هذا سيجلب من الجدولين معاً! ✅

---

### عرض المنتجات بتغيير السعر:

```dart
final result = await supabase
    .rpc('get_price_changed_products', params: {'days_ago': 30})
    .execute();
```

---

## ✅ الخلاصة

### قبل التحديث ❌:
- `distributor_products` لم يكن يدعم Expire Soon
- `distributor_products` لم يكن يدعم Price Action
- الإشعارات فقط من `distributor_ocr_products`

### بعد التحديث ✅:
- ✅ `distributor_products` يدعم Expire Soon
- ✅ `distributor_products` يدعم Price Action
- ✅ تتبع تلقائي للسعر القديم
- ✅ Views و Functions موحّدة للجدولين
- ✅ الإشعارات من جميع الجداول

---

## 📁 الملفات المُحدّثة:

1. ✅ `supabase/migrations/20250120_add_tracking_to_distributor_products.sql` - جديد
2. ✅ `supabase/migrations/20250120_add_product_notification_triggers.sql` - مُحدّث
3. ✅ `notification_webhook_server.js` - مُحدّث
4. ✅ `UPDATE_DISTRIBUTOR_PRODUCTS_NOTIFICATIONS.md` - هذا الملف

---

**جاهز للتطبيق! 🚀**
