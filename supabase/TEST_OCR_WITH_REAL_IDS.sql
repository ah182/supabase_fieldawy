-- ==========================================
-- اختبار OCR Function مع IDs حقيقية
-- ==========================================

-- IDs من Database:
-- distributor_id: d2dc420f-bdf4-4dd9-8212-279cb74922a9
-- ocr_product_id: 71487abd-e315-4697-8b67-16ff17ade084

-- 1️⃣ امسح views
UPDATE distributor_ocr_products SET views = 0;

-- 2️⃣ اختبر Function 3 مرات
SELECT * FROM increment_ocr_product_views(
    'd2dc420f-bdf4-4dd9-8212-279cb74922a9',
    '71487abd-e315-4697-8b67-16ff17ade084'
);

SELECT * FROM increment_ocr_product_views(
    'd2dc420f-bdf4-4dd9-8212-279cb74922a9',
    '71487abd-e315-4697-8b67-16ff17ade084'
);

SELECT * FROM increment_ocr_product_views(
    'd2dc420f-bdf4-4dd9-8212-279cb74922a9',
    '71487abd-e315-4697-8b67-16ff17ade084'
);

-- 3️⃣ تحقق من النتيجة
SELECT 
    distributor_id::TEXT,
    ocr_product_id::TEXT,
    distributor_name,
    views
FROM distributor_ocr_products 
WHERE ocr_product_id::TEXT = '71487abd-e315-4697-8b67-16ff17ade084';

-- يجب أن ترى views = 3 ✅


-- 4️⃣ إذا لم يعمل - تحقق من الصف
SELECT * 
FROM distributor_ocr_products 
WHERE distributor_id = 'd2dc420f-bdf4-4dd9-8212-279cb74922a9'::UUID
AND ocr_product_id = '71487abd-e315-4697-8b67-16ff17ade084'::UUID;


-- 5️⃣ UPDATE يدوي للتأكد
UPDATE distributor_ocr_products 
SET views = 999
WHERE distributor_id = 'd2dc420f-bdf4-4dd9-8212-279cb74922a9'::UUID
AND ocr_product_id = '71487abd-e315-4697-8b67-16ff17ade084'::UUID;

-- تحقق
SELECT distributor_id::TEXT, ocr_product_id::TEXT, views 
FROM distributor_ocr_products 
WHERE views = 999;

-- إذا رأيت views = 999 → UPDATE يدوي يعمل
-- إذا لم ترَ شيء → مشكلة في RLS أو الجدول


-- ==========================================
-- النتيجة المتوقعة:
-- ==========================================
-- من الخطوة 2: success = true, message = "Updated successfully", rows_affected = 1
-- من الخطوة 3: views = 3
-- من الخطوة 5: views = 999
