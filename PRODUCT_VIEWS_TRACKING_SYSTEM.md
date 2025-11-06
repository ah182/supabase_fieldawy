# 📊 نظام تتبع المشاهدات المتكامل

## ✅ المشكلة التي تم حلها

**المشكلة:** جدول `product_views` كان فارغاً لأن النظام القديم كان يزيد فقط عمود `views` في جداول المنتجات، ولا يسجل في جدول `product_views`.

**الحل:** نظام متكامل يسجل كل مشاهدة في جدول `product_views` مع معلومات المستخدم والموقع.

---

## 🎯 النظام الجديد

### **1. جدول product_views المحدث**

```sql
CREATE TABLE public.product_views (
  id UUID PRIMARY KEY,
  product_id TEXT NOT NULL,        -- يدعم جميع أنواع IDs
  user_id UUID,                    -- معرف المستخدم
  user_role TEXT,                  -- دور المستخدم
  product_type TEXT,               -- نوع المنتج
  viewed_at TIMESTAMP              -- وقت المشاهدة
);
```

**الأنواع المدعومة:**
- `regular` - منتجات عادية
- `ocr` - منتجات OCR
- `surgical` - أدوات جراحية
- `offer` - عروض
- `course` - كورسات
- `book` - كتب

---

## 📋 الملفات المعدلة

### **1. SQL Migration**
📁 `supabase/migrations/create_product_views_tracking.sql`

**المحتويات:**
- ✅ إنشاء/تحديث جدول `product_views`
- ✅ Indexes للأداء
- ✅ RLS Policies
- ✅ Function رئيسية: `track_product_view()`
- ✅ Functions مساعدة لكل نوع منتج

### **2. Flutter - product_card.dart**
📁 `lib/widgets/product_card.dart`

**التغييرات:**
- ✅ تحديث `_incrementProductViews()` لاستخدام النظام الجديد
- ✅ إضافة `_trackView()` للتسجيل
- ✅ دعم جميع أنواع المنتجات

### **3. Flutter - product_dialogs.dart**
📁 `lib/features/home/presentation/widgets/product_dialogs.dart`

**التغييرات:**
- ✅ تحديث `_incrementProductViews()` في الديالوجات
- ✅ استخدام `track_product_view()`

---

## 🔧 كيف يعمل النظام

### **الخطوات:**

```
1. المستخدم يشاهد منتج
        ↓
2. Flutter يستدعي _incrementProductViews()
        ↓
3. تحديد نوع المنتج (regular/ocr/surgical/offer)
        ↓
4. استدعاء track_product_view() في Supabase
        ↓
5. Function تسجل في product_views:
   - product_id
   - user_id (من auth.uid())
   - user_role (من جدول users)
   - product_type
   - viewed_at (الآن)
        ↓
6. Function تزيد عداد views في الجدول المناسب:
   - distributor_products (للمنتجات العادية)
   - distributor_ocr_products (لمنتجات OCR)
   - distributor_surgical_tools (للأدوات الجراحية)
   - offers (للعروض)
```

---

## 📊 Functions المتاحة

### **1. Function الرئيسية**
```sql
track_product_view(p_product_id TEXT, p_product_type TEXT)
```
- تسجل المشاهدة في `product_views`
- تزيد العداد في الجدول المناسب
- تحصل على معلومات المستخدم تلقائياً

### **2. Functions المساعدة**
```sql
track_regular_product_view(p_product_id TEXT)
track_ocr_product_view(p_product_id TEXT)
track_surgical_tool_view(p_product_id TEXT)
track_offer_view(p_product_id TEXT)
track_course_view(p_product_id TEXT)
track_book_view(p_product_id TEXT)
```

---

## 🚀 كيفية التطبيق

### **الخطوة 1: تشغيل SQL Migration**

1. افتح Supabase Dashboard
2. اذهب إلى SQL Editor
3. افتح ملف `supabase/migrations/create_product_views_tracking.sql`
4. انسخ المحتوى والصقه
5. اضغط **Run**

### **الخطوة 2: اختبار النظام**

```dart
// في Flutter
Supabase.instance.client.rpc('track_product_view', params: {
  'p_product_id': '123',
  'p_product_type': 'regular',
});
```

### **الخطوة 3: التحقق من البيانات**

```sql
-- عرض آخر 10 مشاهدات
SELECT * FROM product_views 
ORDER BY viewed_at DESC 
LIMIT 10;

-- عدد المشاهدات لكل منتج
SELECT product_id, COUNT(*) as views
FROM product_views
GROUP BY product_id
ORDER BY views DESC;

-- المشاهدات حسب المحافظة
SELECT u.governorates, COUNT(*) as views
FROM product_views pv
JOIN users u ON pv.user_id = u.uid
WHERE u.governorates IS NOT NULL
GROUP BY u.governorates;
```

---

## 📈 البيانات المسجلة

### **لكل مشاهدة:**
- ✅ **product_id**: معرف المنتج
- ✅ **user_id**: معرف المستخدم (أو NULL للزوار)
- ✅ **user_role**: دور المستخدم (doctor, distributor, company, viewer)
- ✅ **product_type**: نوع المنتج
- ✅ **viewed_at**: وقت المشاهدة بالضبط

### **الفوائد:**
- 📊 تحليل سلوك المستخدمين
- 📍 التوزيع الجغرافي للمشاهدات
- ⏰ تحليل الأوقات الأكثر نشاطاً
- 👥 معرفة من يشاهد منتجاتك
- 📈 تتبع نمو المشاهدات

---

## 🔍 استعلامات مفيدة

### **1. أكثر المنتجات مشاهدة**
```sql
SELECT product_id, COUNT(*) as total_views
FROM product_views
WHERE product_type = 'regular'
GROUP BY product_id
ORDER BY total_views DESC
LIMIT 10;
```

### **2. المشاهدات حسب الدور**
```sql
SELECT user_role, COUNT(*) as views
FROM product_views
GROUP BY user_role;
```

### **3. المشاهدات اليومية**
```sql
SELECT DATE(viewed_at) as date, COUNT(*) as views
FROM product_views
WHERE viewed_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(viewed_at)
ORDER BY date DESC;
```

### **4. التوزيع الجغرافي**
```sql
SELECT 
  jsonb_array_elements_text(u.governorates) as governorate,
  COUNT(*) as views
FROM product_views pv
JOIN users u ON pv.user_id = u.uid
WHERE u.governorates IS NOT NULL
GROUP BY governorate
ORDER BY views DESC;
```

---

## ⚠️ ملاحظات مهمة

1. **الأداء**: تم إضافة Indexes على جميع الأعمدة المهمة
2. **الخصوصية**: RLS Policies تسمح بالإدراج للجميع، القراءة للجميع
3. **الزوار**: يتم تسجيل المشاهدات حتى للمستخدمين غير المسجلين (user_id = NULL)
4. **الأخطاء**: النظام لا يرفع أخطاء، فقط يسجل في NOTICE

---

## 🎯 النتيجة

الآن جدول `product_views` سيمتلئ تلقائياً بالبيانات، ويمكنك:
- ✅ رؤية التوزيع الجغرافي الفعلي
- ✅ تحليل سلوك المستخدمين
- ✅ معرفة أكثر المنتجات شعبية
- ✅ تتبع نمو المشاهدات بمرور الوقت

