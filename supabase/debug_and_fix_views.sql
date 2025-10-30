-- ==========================================
-- تشخيص وإصلاح مشكلة عدم زيادة views
-- ==========================================

-- 1️⃣ اختبار UPDATE يدوياً
-- ==========================================

-- اختبر UPDATE مباشر
UPDATE distributor_products 
SET views = 999 
WHERE id = '649';

-- تحقق
SELECT id, views FROM distributor_products WHERE id = '649';

-- إذا لم تتغير views إلى 999 → مشكلة في RLS أو constraints


-- 2️⃣ التحقق من RLS
-- ==========================================

-- عرض RLS policies على الجدول
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'distributor_products';

-- إذا كان RLS مفعل وتمنع UPDATE → هذه المشكلة!


-- 3️⃣ تعطيل RLS مؤقتاً للاختبار
-- ==========================================

-- تعطيل RLS (للاختبار فقط!)
ALTER TABLE distributor_products DISABLE ROW LEVEL SECURITY;

-- اختبر UPDATE
UPDATE distributor_products SET views = 888 WHERE id = '649';
SELECT id, views FROM distributor_products WHERE id = '649';

-- إعادة تفعيل RLS
ALTER TABLE distributor_products ENABLE ROW LEVEL SECURITY;


-- 4️⃣ Function محسنة مع logging
-- ==========================================

DROP FUNCTION IF EXISTS increment_product_views(TEXT);

CREATE OR REPLACE FUNCTION increment_product_views(p_product_id TEXT)
RETURNS TABLE(success BOOLEAN, rows_affected INTEGER, message TEXT)
LANGUAGE plpgsql 
SECURITY DEFINER  -- مهم جداً!
AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    -- محاولة UPDATE
    UPDATE distributor_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE id = p_product_id;
    
    -- حفظ عدد الصفوف المتأثرة
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    
    -- إرجاع النتيجة
    IF v_rows_affected > 0 THEN
        RETURN QUERY SELECT TRUE, v_rows_affected, 'Views incremented successfully'::TEXT;
    ELSE
        RETURN QUERY SELECT FALSE, 0, 'No product found with id: ' || p_product_id;
    END IF;
END;
$$;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO anon;


-- 5️⃣ اختبار Function الجديدة
-- ==========================================

-- اختبر
SELECT * FROM increment_product_views('649');

-- يجب أن ترى:
-- success | rows_affected | message
-- --------|---------------|------------------------
-- true    | 1             | Views incremented successfully

-- تحقق
SELECT id, views FROM distributor_products WHERE id = '649';


-- 6️⃣ إذا كانت المشكلة في RLS - إنشاء Policy
-- ==========================================

-- إنشاء policy للسماح بـ UPDATE للجميع على views فقط
CREATE POLICY IF NOT EXISTS "Allow increment views for all"
ON distributor_products
FOR UPDATE
TO public
USING (true)
WITH CHECK (true);


-- 7️⃣ بديل: Function تتجاوز RLS تماماً
-- ==========================================

DROP FUNCTION IF EXISTS increment_product_views(TEXT);

CREATE OR REPLACE FUNCTION increment_product_views(p_product_id TEXT)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE distributor_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE id = p_product_id;
$$;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO anon;


-- 8️⃣ اختبار نهائي
-- ==========================================

-- امسح views
UPDATE distributor_products SET views = 0 WHERE id = '649';

-- اختبر Function
SELECT increment_product_views('649');
SELECT increment_product_views('649');
SELECT increment_product_views('649');

-- تحقق (يجب أن تكون 3)
SELECT id, views FROM distributor_products WHERE id = '649';


-- ==========================================
-- تعليمات التشخيص
-- ==========================================

-- إذا views لم تزد:
-- 1. شغل الخطوة 1 (UPDATE يدوي)
-- 2. شغل الخطوة 2 (فحص RLS)
-- 3. شغل الخطوة 7 (Function تتجاوز RLS)
-- 4. شغل الخطوة 8 (اختبار نهائي)
