-- ==========================================
-- اختبار نظام المشاهدات يدوياً
-- ==========================================

-- 1️⃣ تحقق من وجود Functions
-- ==========================================
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name IN (
    'increment_product_views',
    'increment_ocr_product_views',
    'increment_surgical_tool_views'
)
AND routine_schema = 'public';

-- يجب أن ترى:
-- increment_product_views       | FUNCTION
-- increment_ocr_product_views   | FUNCTION
-- increment_surgical_tool_views | FUNCTION


-- 2️⃣ تحقق من عمود views في الجداول
-- ==========================================
-- للمنتجات العادية
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'distributor_products' 
AND column_name = 'views';

-- لمنتجات OCR
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'distributor_ocr_products' 
AND column_name = 'views';

-- للأدوات الجراحية
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'distributor_surgical_tools' 
AND column_name = 'views';


-- 3️⃣ جلب أول منتج للاختبار
-- ==========================================
SELECT id, name, views 
FROM distributor_products 
LIMIT 1;

-- انسخ الـ ID من النتيجة


-- 4️⃣ اختبر Function يدوياً
-- ==========================================
-- استبدل 'YOUR_PRODUCT_ID' بالـ ID الحقيقي من الخطوة 3
SELECT increment_product_views('YOUR_PRODUCT_ID'::UUID);

-- مثال:
-- SELECT increment_product_views('550e8400-e29b-41d4-a716-446655440000'::UUID);


-- 5️⃣ تحقق من أن المشاهدات زادت
-- ==========================================
SELECT id, name, views 
FROM distributor_products 
WHERE id = 'YOUR_PRODUCT_ID'::UUID;

-- يجب أن ترى views = 1 الآن!


-- 6️⃣ زيادة مشاهدات لعدة منتجات للاختبار
-- ==========================================
DO $$
DECLARE
  product_record RECORD;
BEGIN
  FOR product_record IN 
    SELECT id FROM distributor_products LIMIT 10
  LOOP
    UPDATE distributor_products 
    SET views = 15 
    WHERE id = product_record.id;
  END LOOP;
END $$;


-- 7️⃣ تحقق من النتيجة
-- ==========================================
SELECT name, views 
FROM distributor_products 
WHERE views > 0 
LIMIT 10;


-- 8️⃣ للأدوات الجراحية (اختياري)
-- ==========================================
-- جلب أول أداة
SELECT id, views 
FROM distributor_surgical_tools 
LIMIT 1;

-- اختبر Function
-- استبدل YOUR_TOOL_ID بالـ ID الحقيقي
-- SELECT increment_surgical_tool_views('YOUR_TOOL_ID'::UUID);

-- تحقق من الزيادة
-- SELECT id, views 
-- FROM distributor_surgical_tools 
-- WHERE id = 'YOUR_TOOL_ID'::UUID;


-- ==========================================
-- ✅ إذا نجحت الخطوة 4 و 5
-- ==========================================
-- المشكلة في استدعاء Function من Flutter
-- انتقل لفحص الكود في Flutter


-- ==========================================
-- ❌ إذا فشلت الخطوة 4
-- ==========================================
-- Function غير موجودة أو بها خطأ
-- أعد تطبيق add_views_to_products.sql
