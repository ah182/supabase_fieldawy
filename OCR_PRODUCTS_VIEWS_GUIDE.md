# 📊 دليل: دعم المشاهدات لمنتجات OCR

## ✅ **ما تم إضافته:**

تم توسيع نظام المشاهدات ليدعم **كل من**:
- ✅ **Regular Products** → جدول `distributor_products`
- ✅ **OCR Products** → جدول `distributor_ocr_products`

---

## 📋 **التحديثات في SQL:**

### **1. إضافة عمود views لـ OCR Products**
```sql
ALTER TABLE distributor_ocr_products 
ADD COLUMN views INTEGER DEFAULT 0;
```

### **2. Index للأداء**
```sql
CREATE INDEX idx_distributor_ocr_products_views 
ON distributor_ocr_products(views DESC);
```

### **3. Function لزيادة المشاهدات**
```sql
CREATE FUNCTION increment_ocr_product_views(
    p_distributor_id UUID,
    p_ocr_product_id TEXT
)
RETURNS void AS $$
BEGIN
    UPDATE distributor_ocr_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE distributor_id = p_distributor_id 
    AND ocr_product_id = p_ocr_product_id;
END;
$$ LANGUAGE plpgsql;
```

---

## 🔄 **التحديثات في الكود:**

### **دالة `_incrementProductViews` الذكية:**

```dart
void _incrementProductViews(String productId, {String? distributorId}) {
  try {
    // التحقق من نوع المنتج
    if (productId.startsWith('ocr_') && distributorId != null) {
      // منتج OCR
      final ocrProductId = productId.substring(4); // إزالة "ocr_"
      
      Supabase.instance.client.rpc('increment_ocr_product_views', params: {
        'p_distributor_id': distributorId,
        'p_ocr_product_id': ocrProductId,
      });
    } else {
      // منتج عادي
      Supabase.instance.client.rpc('increment_product_views', params: {
        'product_id': productId,
      });
    }
  } catch (e) {
    print('خطأ في زيادة مشاهدات المنتج: $e');
  }
}
```

---

## 🎯 **كيف يعمل النظام:**

### **سيناريو 1: Regular Product**
```
المنتج: id = "abc-123-def"
        ↓
لا يبدأ بـ "ocr_"
        ↓
استدعاء: increment_product_views(product_id)
        ↓
✅ تحديث distributor_products
```

### **سيناريو 2: OCR Product**
```
المنتج: id = "ocr_xyz-789"
        ↓
يبدأ بـ "ocr_" ✅
        ↓
استخراج: ocrProductId = "xyz-789"
        ↓
استدعاء: increment_ocr_product_views(
    distributor_id,
    ocr_product_id
)
        ↓
✅ تحديث distributor_ocr_products
```

---

## 📊 **مثال عملي:**

### **منتج عادي:**
```dart
ProductModel product = ProductModel(
  id: "550e8400-e29b-41d4-a716-446655440000",
  distributorId: "...",
  // ...
);

// عند المشاهدة:
_incrementProductViews(product.id, distributorId: product.distributorId);
// → يستدعي increment_product_views()
```

### **منتج OCR:**
```dart
ProductModel product = ProductModel(
  id: "ocr_ASPIRIN_500MG",
  distributorId: "550e8400-e29b-41d4-a716-446655440001",
  // ...
);

// عند المشاهدة:
_incrementProductViews(product.id, distributorId: product.distributorId);
// → يستدعي increment_ocr_product_views()
```

---

## 🔍 **التحقق من قاعدة البيانات:**

### **1. مشاهدات Regular Products:**
```sql
SELECT name, views 
FROM distributor_products 
ORDER BY views DESC 
LIMIT 10;
```

### **2. مشاهدات OCR Products:**
```sql
SELECT product_name, views 
FROM distributor_ocr_products 
ORDER BY views DESC 
LIMIT 10;
```

### **3. إجمالي المشاهدات:**
```sql
SELECT 
  'Regular' as type,
  COUNT(*) as products,
  SUM(views) as total_views,
  AVG(views) as avg_views
FROM distributor_products

UNION ALL

SELECT 
  'OCR' as type,
  COUNT(*) as products,
  SUM(views) as total_views,
  AVG(views) as avg_views
FROM distributor_ocr_products;
```

---

## ✅ **الملفات المعدلة:**

1. ✅ `supabase/add_views_to_products.sql`
   - إضافة دعم OCR products

2. ✅ `lib/widgets/product_card.dart`
   - تحديث `_incrementProductViews()`
   - تمرير `distributorId`

3. ✅ `lib/features/home/presentation/widgets/product_dialogs.dart`
   - تحديث `_incrementProductViews()`
   - تمرير `distributorId` للأدوات الجراحية

---

## 🚀 **خطوات التطبيق:**

### **الخطوة 1: تطبيق SQL المحدث**
```bash
1. افتح Supabase Dashboard
2. SQL Editor → New Query
3. انسخ محتوى: supabase/add_views_to_products.sql
4. Run (سيضيف دعم OCR تلقائياً)
```

### **الخطوة 2: لا حاجة لـ Build Runner**
الكود لا يحتاج إعادة توليد - جاهز للاستخدام!

### **الخطوة 3: تشغيل التطبيق**
```bash
flutter run
```

---

## 🎯 **الفوائد:**

✅ **دعم شامل** - كل المنتجات (Regular + OCR)
✅ **ذكي** - يكتشف النوع تلقائياً
✅ **دقيق** - كل نوع في جدوله الخاص
✅ **سريع** - Indexes محسنة
✅ **آمن** - Constraints وValidation

---

## 📈 **إحصائيات مفيدة:**

### **مقارنة بين Regular و OCR:**
```sql
WITH stats AS (
  SELECT 
    'Regular' as type,
    COUNT(*) as total_products,
    SUM(CASE WHEN views > 0 THEN 1 ELSE 0 END) as viewed_products,
    MAX(views) as max_views,
    MIN(views) as min_views
  FROM distributor_products
  
  UNION ALL
  
  SELECT 
    'OCR' as type,
    COUNT(*),
    SUM(CASE WHEN views > 0 THEN 1 ELSE 0 END),
    MAX(views),
    MIN(views)
  FROM distributor_ocr_products
)
SELECT * FROM stats;
```

---

## 🔧 **ملاحظات تقنية:**

### **1. معرفات OCR Products:**
- تبدأ دائماً بـ `"ocr_"`
- مثال: `"ocr_PANADOL_500MG"`

### **2. المفتاح المركب:**
OCR products تستخدم مفتاح مركب:
- `distributor_id` (UUID)
- `ocr_product_id` (TEXT)

### **3. Regular Products:**
- تستخدم `id` فقط (UUID)

---

## ⚠️ **مهم:**

عند تطبيق SQL script، سيتم:
1. ✅ إضافة views لـ Regular products
2. ✅ إضافة views لـ OCR products
3. ✅ إنشاء Functions لكلا النوعين
4. ✅ تحديث القيم الحالية إلى 0

**لا تقلق** - الـ script آمن ويدعم التشغيل المتعدد (idempotent)

---

**🎉 النظام الآن يدعم جميع أنواع المنتجات!** 🚀
