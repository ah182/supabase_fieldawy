-- ==========================================
-- إيجاد IDs الحقيقية واختبار views
-- ==========================================

-- 1️⃣ عرض أول 10 صفوف من الجدول
-- ==========================================
SELECT id, product_id, distributor_id, views 
FROM distributor_products 
LIMIT 10;

-- انسخ ID حقيقي من النتيجة!


-- 2️⃣ البحث عن IDs من Console
-- ==========================================
-- من Console رأينا: 649, 592, 1129, 733, 920

-- تحقق هل موجودة (قد تكون بتنسيق مختلف)
SELECT id, product_id, views 
FROM distributor_products 
WHERE id LIKE '%649%';

SELECT id, product_id, views 
FROM distributor_products 
WHERE id LIKE '%592%';


-- 3️⃣ عرض جميع IDs التي تحتوي على أرقام
-- ==========================================
SELECT id, product_id, views 
FROM distributor_products 
WHERE id ~ '^[0-9]+$'  -- IDs التي هي أرقام فقط
LIMIT 20;


-- 4️⃣ اختبار Function مع ID حقيقي
-- ==========================================

-- خذ أول ID من الجدول
DO $$
DECLARE
    v_first_id TEXT;
BEGIN
    SELECT id INTO v_first_id 
    FROM distributor_products 
    LIMIT 1;
    
    RAISE NOTICE 'First ID: %', v_first_id;
    
    -- اختبر Function
    PERFORM increment_product_views(v_first_id);
    PERFORM increment_product_views(v_first_id);
    PERFORM increment_product_views(v_first_id);
END $$;

-- تحقق من النتيجة
SELECT id, views 
FROM distributor_products 
WHERE views > 0
LIMIT 5;


-- 5️⃣ إنشاء جدول اختبار صغير
-- ==========================================

-- إضافة سطر اختبار
INSERT INTO distributor_products (id, views)
VALUES ('test_123', 0)
ON CONFLICT (id) DO NOTHING;

-- اختبر Function
SELECT increment_product_views('test_123');
SELECT increment_product_views('test_123');
SELECT increment_product_views('test_123');

-- تحقق
SELECT id, views FROM distributor_products WHERE id = 'test_123';

-- يجب أن ترى views = 3 ✅


-- 6️⃣ التحقق من نوع البيانات الفعلي
-- ==========================================
SELECT 
    id,
    pg_typeof(id) as id_type,
    length(id) as id_length,
    views
FROM distributor_products 
LIMIT 5;


-- 7️⃣ اختبار شامل مع أول منتج موجود
-- ==========================================

-- احفظ ID أول منتج
WITH first_product AS (
    SELECT id FROM distributor_products LIMIT 1
)
SELECT 
    'Before: ' || COALESCE(views::TEXT, 'null') as status,
    id
FROM distributor_products 
WHERE id = (SELECT id FROM first_product);

-- زد views
SELECT increment_product_views((SELECT id FROM distributor_products LIMIT 1));
SELECT increment_product_views((SELECT id FROM distributor_products LIMIT 1));
SELECT increment_product_views((SELECT id FROM distributor_products LIMIT 1));

-- تحقق
WITH first_product AS (
    SELECT id FROM distributor_products LIMIT 1
)
SELECT 
    'After: ' || COALESCE(views::TEXT, 'null') as status,
    id
FROM distributor_products 
WHERE id = (SELECT id FROM first_product);


-- ==========================================
-- ✅ تعليمات
-- ==========================================
-- 1. شغل الخطوة 1 - انسخ ID حقيقي
-- 2. استبدل 'REAL_ID' في الخطوة التالية بالـ ID الحقيقي
-- 3. شغل:
--    SELECT increment_product_views('REAL_ID');
--    SELECT id, views FROM distributor_products WHERE id = 'REAL_ID';
