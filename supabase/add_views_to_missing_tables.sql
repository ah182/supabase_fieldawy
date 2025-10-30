-- ==========================================
-- إضافة عمود views للجداول الناقصة
-- ==========================================

-- 1️⃣ إضافة views لجدول surgical_tools
-- ==========================================
ALTER TABLE distributor_surgical_tools 
ADD COLUMN IF NOT EXISTS views INTEGER DEFAULT 0;

-- إضافة constraint (يتخطى إذا كان موجود)
DO $$ 
BEGIN
    ALTER TABLE distributor_surgical_tools 
    ADD CONSTRAINT check_surgical_views_non_negative CHECK (views >= 0);
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- إضافة index
CREATE INDEX IF NOT EXISTS idx_surgical_tools_views 
ON distributor_surgical_tools (views DESC);


-- 2️⃣ التحقق من عمود views في OCR (قد يكون موجود)
-- ==========================================
ALTER TABLE distributor_ocr_products 
ADD COLUMN IF NOT EXISTS views INTEGER DEFAULT 0;

-- إضافة constraint (يتخطى إذا كان موجود)
DO $$ 
BEGIN
    ALTER TABLE distributor_ocr_products 
    ADD CONSTRAINT check_ocr_views_non_negative CHECK (views >= 0);
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- إضافة index
CREATE INDEX IF NOT EXISTS idx_ocr_products_views 
ON distributor_ocr_products (views DESC);


-- 3️⃣ تحديث Functions
-- ==========================================

-- حذف Functions القديمة
DROP FUNCTION IF EXISTS increment_product_views(TEXT);
DROP FUNCTION IF EXISTS increment_ocr_product_views(TEXT, TEXT);
DROP FUNCTION IF EXISTS increment_surgical_tool_views(TEXT);


-- 4️⃣ للمنتجات العادية
-- ==========================================
CREATE OR REPLACE FUNCTION increment_product_views(p_product_id TEXT)
RETURNS void 
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE distributor_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE product_id = p_product_id;
$$;


-- 5️⃣ لمنتجات OCR - مع البحث الصحيح
-- ==========================================
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
    -- جرب بـ UUID للـ distributor_id
    UPDATE distributor_ocr_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE distributor_id = p_distributor_id::UUID
    AND ocr_product_id = p_ocr_product_id;
    
    -- إذا لم ينجح، جرب بـ TEXT
    IF NOT FOUND THEN
        UPDATE distributor_ocr_products 
        SET views = COALESCE(views, 0) + 1 
        WHERE distributor_id::TEXT = p_distributor_id
        AND ocr_product_id = p_ocr_product_id;
    END IF;
END;
$$;


-- 6️⃣ للأدوات الجراحية
-- ==========================================
CREATE OR REPLACE FUNCTION increment_surgical_tool_views(p_tool_id TEXT)
RETURNS void 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- جرب بـ UUID
    UPDATE distributor_surgical_tools 
    SET views = COALESCE(views, 0) + 1 
    WHERE id = p_tool_id::UUID;
    
    -- إذا لم ينجح، جرب بـ TEXT
    IF NOT FOUND THEN
        UPDATE distributor_surgical_tools 
        SET views = COALESCE(views, 0) + 1 
        WHERE id::TEXT = p_tool_id;
    END IF;
END;
$$;


-- 7️⃣ منح الصلاحيات
-- ==========================================
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO anon;

GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(TEXT, TEXT) TO anon;

GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(TEXT) TO anon;


-- 8️⃣ اختبار
-- ==========================================

-- اختبار المنتجات العادية
UPDATE distributor_products SET views = 0 WHERE product_id = '649';
SELECT increment_product_views('649');
SELECT increment_product_views('649');
SELECT increment_product_views('649');
SELECT product_id, views FROM distributor_products WHERE product_id = '649';
-- يجب أن ترى views = 3 ✅


-- اختبار OCR (إذا كان لديك بيانات)
-- احصل على أول OCR product
-- SELECT distributor_id, ocr_product_id, views FROM distributor_ocr_products LIMIT 1;
-- ثم استخدم الـ IDs في:
-- SELECT increment_ocr_product_views('DISTRIBUTOR_ID', 'OCR_PRODUCT_ID');
-- SELECT distributor_id, ocr_product_id, views FROM distributor_ocr_products WHERE ocr_product_id = 'OCR_PRODUCT_ID';


-- اختبار Surgical Tools (إذا كان لديك بيانات)
-- احصل على أول surgical tool
-- SELECT id, views FROM distributor_surgical_tools LIMIT 1;
-- ثم استخدم الـ ID في:
-- SELECT increment_surgical_tool_views('TOOL_ID');
-- SELECT id, views FROM distributor_surgical_tools WHERE id::TEXT = 'TOOL_ID';


-- 9️⃣ عرض النتائج
-- ==========================================

-- المنتجات العادية
SELECT 'Products' as type, COUNT(*) as total, SUM(views) as total_views
FROM distributor_products
WHERE views > 0;

-- OCR Products
SELECT 'OCR Products' as type, COUNT(*) as total, SUM(views) as total_views
FROM distributor_ocr_products
WHERE views > 0;

-- Surgical Tools
SELECT 'Surgical Tools' as type, COUNT(*) as total, SUM(views) as total_views
FROM distributor_surgical_tools
WHERE views > 0;


-- ==========================================
-- ✅ تم! جميع الجداول جاهزة
-- ==========================================
