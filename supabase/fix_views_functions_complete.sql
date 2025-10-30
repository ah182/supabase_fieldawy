-- ==========================================
-- ✅ حل نهائي: إصلاح Functions للمشاهدات
-- ==========================================
-- يحذف جميع النسخ القديمة ويعيد الإنشاء بشكل صحيح
-- ==========================================

-- 1️⃣ حذف جميع Functions القديمة
-- ==========================================
DROP FUNCTION IF EXISTS increment_product_views(UUID);
DROP FUNCTION IF EXISTS increment_product_views(TEXT);
DROP FUNCTION IF EXISTS increment_product_views(product_id TEXT);

DROP FUNCTION IF EXISTS increment_ocr_product_views(UUID, TEXT);
DROP FUNCTION IF EXISTS increment_ocr_product_views(TEXT, TEXT);

DROP FUNCTION IF EXISTS increment_surgical_tool_views(UUID);
DROP FUNCTION IF EXISTS increment_surgical_tool_views(TEXT);


-- 2️⃣ إنشاء Functions الجديدة بأسماء parameters واضحة
-- ==========================================

-- ✅ للمنتجات العادية
CREATE OR REPLACE FUNCTION increment_product_views(p_product_id TEXT)
RETURNS void 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
BEGIN
    UPDATE distributor_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE id::TEXT = p_product_id;
END;
$$;

-- ✅ لمنتجات OCR
CREATE OR REPLACE FUNCTION increment_ocr_product_views(
    p_distributor_id TEXT,
    p_ocr_product_id TEXT
)
RETURNS void 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
BEGIN
    UPDATE distributor_ocr_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE distributor_id::TEXT = p_distributor_id 
    AND ocr_product_id = p_ocr_product_id;
END;
$$;

-- ✅ للأدوات الجراحية
CREATE OR REPLACE FUNCTION increment_surgical_tool_views(p_tool_id TEXT)
RETURNS void 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
BEGIN
    UPDATE distributor_surgical_tools 
    SET views = COALESCE(views, 0) + 1 
    WHERE id::TEXT = p_tool_id;
END;
$$;


-- 3️⃣ منح الصلاحيات
-- ==========================================
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO anon;

GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO anon;

GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(TEXT) TO anon;


-- 4️⃣ اختبار Functions
-- ==========================================
-- جلب أول منتج للاختبار
-- SELECT id, name, views FROM distributor_products LIMIT 1;

-- اختبر Function (استبدل '733' بـ ID حقيقي)
-- SELECT increment_product_views('733');

-- تحقق من الزيادة
-- SELECT id, name, views FROM distributor_products WHERE id::TEXT = '733';
-- يجب أن ترى views = 1 ✅


-- 5️⃣ تحقق من Functions المثبتة
-- ==========================================
-- SELECT routine_name, routine_type 
-- FROM information_schema.routines 
-- WHERE routine_name LIKE '%increment%view%'
-- AND routine_schema = 'public';


-- ==========================================
-- ✅ تم بنجاح! النظام جاهز للعمل
-- ==========================================
