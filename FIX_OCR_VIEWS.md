# 🔧 إصلاح OCR Products Views

## ❌ **المشكلة:**
```
distributor_ocr_products.views = 0 دائماً
```

---

## 🔍 **التشخيص السريع (3 خطوات):**

### **الخطوة 1: تحقق من بنية الجدول**

**في Supabase SQL Editor:**

```sql
-- عرض أعمدة الجدول
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'distributor_ocr_products';

-- عرض أول صف
SELECT * FROM distributor_ocr_products LIMIT 1;
```

**انسخ نتيجة الصف الأول!** ستحتاجها للاختبار.

---

### **الخطوة 2: اختبار UPDATE يدوي**

```sql
-- جرب UPDATE مباشر مع IDs حقيقية
UPDATE distributor_ocr_products 
SET views = 999
WHERE distributor_id::TEXT = 'YOUR_DISTRIBUTOR_ID'
AND ocr_product_id = 'YOUR_OCR_PRODUCT_ID';

-- تحقق
SELECT distributor_id, ocr_product_id, views 
FROM distributor_ocr_products 
WHERE views = 999;
```

**إذا نجح (views = 999) → المشكلة في Function**

---

### **الخطوة 3: إصلاح Function**

**انسخ والصق هذا:**

```sql
DROP FUNCTION IF EXISTS increment_ocr_product_views(TEXT, TEXT);

CREATE OR REPLACE FUNCTION increment_ocr_product_views(
    p_distributor_id TEXT,
    p_ocr_product_id TEXT
)
RETURNS void 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- إزالة prefix "ocr_" إذا كان موجوداً
    IF p_ocr_product_id LIKE 'ocr_%' THEN
        p_ocr_product_id := substring(p_ocr_product_id from 5);
    END IF;
    
    -- UPDATE مع logging
    UPDATE distributor_ocr_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE distributor_id::TEXT = p_distributor_id
    AND ocr_product_id = p_ocr_product_id;
    
    -- إذا لم ينجح، جرب UUID
    IF NOT FOUND THEN
        UPDATE distributor_ocr_products 
        SET views = COALESCE(views, 0) + 1 
        WHERE distributor_id = p_distributor_id::UUID
        AND ocr_product_id = p_ocr_product_id;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO anon;
```

**Run**

---

## 🧪 **اختبار Function:**

```sql
-- امسح views
UPDATE distributor_ocr_products SET views = 0;

-- احصل على IDs حقيقية
SELECT 
    distributor_id::TEXT as dist_id,
    ocr_product_id as ocr_id
FROM distributor_ocr_products 
LIMIT 1;
```

**انسخ الـ IDs من النتيجة واستخدمها:**

```sql
-- استبدل بالـ IDs الحقيقية
SELECT increment_ocr_product_views('YOUR_DIST_ID', 'YOUR_OCR_ID');
SELECT increment_ocr_product_views('YOUR_DIST_ID', 'YOUR_OCR_ID');
SELECT increment_ocr_product_views('YOUR_DIST_ID', 'YOUR_OCR_ID');

-- تحقق
SELECT distributor_id, ocr_product_id, views 
FROM distributor_ocr_products 
WHERE ocr_product_id = 'YOUR_OCR_ID';
```

**النتيجة المتوقعة:**
```
distributor_id | ocr_product_id | views
---------------|----------------|------
...            | YOUR_OCR_ID    | 3     ← ✅ نجح!
```

---

## 🎯 **السبب المحتمل:**

### **المشكلة 1: ocr_ prefix**
```dart
// في Flutter
productId.startsWith('ocr_')
final ocrProductId = productId.substring(4);  // يزيل "ocr_"
```

**Function الآن تتعامل مع هذا تلقائياً!**

### **المشكلة 2: distributor_id type**
```sql
-- قد يكون UUID أو TEXT
-- Function الآن تجرب الاثنين
```

---

## 🚀 **في Flutter:**

**بعد إصلاح Function:**

```bash
flutter run
```

**افتح المنتجات التي تحتوي OCR**

**Console يجب أن يعرض:**
```
🔵 Incrementing views for product: ocr_123
✅ OCR product views incremented successfully
```

**بعد دقيقة - في Supabase:**

```sql
SELECT ocr_product_id, views 
FROM distributor_ocr_products 
WHERE views > 0 
ORDER BY views DESC 
LIMIT 5;
```

**✅ يجب أن ترى views > 0! 🎉**

---

## 📋 **Checklist:**

- [ ] ✅ عرضت بنية الجدول
- [ ] ✅ اختبرت UPDATE يدوي: نجح
- [ ] ✅ طبقت Function الجديدة
- [ ] ✅ اختبرت Function: views = 3
- [ ] ✅ شغلت `flutter run`
- [ ] ✅ Console: "✅ OCR incremented"
- [ ] ✅ في Supabase: views > 0

---

## 💡 **ملاحظة:**

### **بنية OCR Product ID:**

**من Flutter:**
```
productId = "ocr_123"  ← مع prefix
```

**في Database:**
```
ocr_product_id = "123"  ← بدون prefix
```

**Function الجديدة تزيل prefix تلقائياً!** ✅

---

## 🔧 **للتشخيص الكامل:**

**استخدم:** `debug_ocr_views.sql`

**يحتوي على:**
1. ✅ عرض بنية الجدول
2. ✅ اختبار UPDATE يدوي
3. ✅ Function محسنة مع logging
4. ✅ اختبارات شاملة

---

## 🎉 **الحل النهائي:**

```sql
-- فقط نفذ هذا:
DROP FUNCTION IF EXISTS increment_ocr_product_views(TEXT, TEXT);

CREATE OR REPLACE FUNCTION increment_ocr_product_views(
    p_distributor_id TEXT,
    p_ocr_product_id TEXT
)
RETURNS void 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- إزالة "ocr_" إذا موجود
    IF p_ocr_product_id LIKE 'ocr_%' THEN
        p_ocr_product_id := substring(p_ocr_product_id from 5);
    END IF;
    
    -- UPDATE
    UPDATE distributor_ocr_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE distributor_id::TEXT = p_distributor_id
    AND ocr_product_id = p_ocr_product_id;
    
    -- إذا لم ينجح، جرب UUID
    IF NOT FOUND THEN
        UPDATE distributor_ocr_products 
        SET views = COALESCE(views, 0) + 1 
        WHERE distributor_id = p_distributor_id::UUID
        AND ocr_product_id = p_ocr_product_id;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO anon;
```

**Run → اختبر → flutter run → ✅ يعمل!**

---

**🚀 نفذ الحل الآن!** 👁️✨
