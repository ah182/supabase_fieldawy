-- ==========================================
-- إصلاح: تعديل Functions لقبول TEXT بدلاً من UUID
-- ==========================================
-- المشكلة: product.id ليس UUID بل Integer/Text
-- الحل: تغيير parameter type من UUID إلى TEXT
-- ==========================================

-- 1️⃣ حذف Functions القديمة (جميع الأنواع المحتملة)
DROP FUNCTION IF EXISTS increment_product_views(UUID);
DROP FUNCTION IF EXISTS increment_product_views(TEXT);
DROP FUNCTION IF EXISTS increment_ocr_product_views(UUID, TEXT);
DROP FUNCTION IF EXISTS increment_ocr_product_views(TEXT, TEXT);
DROP FUNCTION IF EXISTS increment_surgical_tool_views(UUID);
DROP FUNCTION IF EXISTS increment_surgical_tool_views(TEXT);

-- 2️⃣ إنشاء Functions جديدة بـ TEXT
-- ==========================================

-- للمنتجات العادية (Regular Products)
CREATE OR REPLACE FUNCTION increment_product_views(p_product_id TEXT)
RETURNS void AS $$
BEGIN
    UPDATE distributor_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE id::TEXT = p_product_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- لمنتجات OCR
CREATE OR REPLACE FUNCTION increment_ocr_product_views(
    p_distributor_id TEXT,
    p_ocr_product_id TEXT
)
RETURNS void AS $$
BEGIN
    UPDATE distributor_ocr_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE distributor_id::TEXT = p_distributor_id 
    AND ocr_product_id = p_ocr_product_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- للأدوات الجراحية (Surgical Tools)
CREATE OR REPLACE FUNCTION increment_surgical_tool_views(p_tool_id TEXT)
RETURNS void AS $$
BEGIN
    UPDATE distributor_surgical_tools 
    SET views = COALESCE(views, 0) + 1 
    WHERE id::TEXT = p_tool_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3️⃣ منح الصلاحيات
-- ==========================================
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO anon;

GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO anon;

GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(TEXT) TO anon;

-- 4️⃣ اختبار
-- ==========================================
-- جلب أول منتج
-- SELECT id, name, views FROM distributor_products LIMIT 1;

-- اختبر (استبدل '733' بـ ID حقيقي من الخطأ في Console)
-- SELECT increment_product_views('733');

-- تحقق من الزيادة
-- SELECT id, name, views FROM distributor_products WHERE id::TEXT = '733';

-- يجب أن تزيد views من 0 إلى 1 ✅

-- ==========================================
-- ✅ تم بنجاح!
-- ==========================================
