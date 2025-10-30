-- ==========================================
-- إضافة عمود المشاهدات لجدول المنتجات
-- ==========================================

-- إضافة عمود views إذا لم يكن موجوداً
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'distributor_products' AND column_name = 'views'
    ) THEN
        ALTER TABLE distributor_products ADD COLUMN views INTEGER DEFAULT 0;
    END IF;
END $$;

-- إنشاء index على عمود views لتحسين الأداء عند الترتيب
CREATE INDEX IF NOT EXISTS idx_distributor_products_views ON distributor_products(views DESC);

-- تحديث القيم الحالية إلى 0 إذا كانت null
UPDATE distributor_products SET views = 0 WHERE views IS NULL;

-- إضافة constraint للتأكد من أن views لا تكون سالبة (إذا لم يكن موجوداً)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'distributor_products' 
        AND constraint_name = 'check_views_non_negative'
    ) THEN
        ALTER TABLE distributor_products 
        ADD CONSTRAINT check_views_non_negative 
        CHECK (views >= 0);
    END IF;
END $$;

-- ==========================================
-- Function لزيادة عدد المشاهدات
-- ==========================================
CREATE OR REPLACE FUNCTION increment_product_views(product_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE distributor_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE id = product_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION increment_product_views(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_product_views(UUID) TO anon;

-- ==========================================
-- إضافة عمود المشاهدات لجدول منتجات OCR
-- ==========================================

-- إضافة عمود views لجدول distributor_ocr_products إذا لم يكن موجوداً
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'distributor_ocr_products' AND column_name = 'views'
    ) THEN
        ALTER TABLE distributor_ocr_products ADD COLUMN views INTEGER DEFAULT 0;
    END IF;
END $$;

-- إنشاء index على عمود views في distributor_ocr_products
CREATE INDEX IF NOT EXISTS idx_distributor_ocr_products_views ON distributor_ocr_products(views DESC);

-- تحديث القيم الحالية إلى 0 إذا كانت null
UPDATE distributor_ocr_products SET views = 0 WHERE views IS NULL;

-- إضافة constraint للتأكد من أن views لا تكون سالبة (إذا لم يكن موجوداً)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'distributor_ocr_products' 
        AND constraint_name = 'check_ocr_views_non_negative'
    ) THEN
        ALTER TABLE distributor_ocr_products 
        ADD CONSTRAINT check_ocr_views_non_negative 
        CHECK (views >= 0);
    END IF;
END $$;

-- ==========================================
-- Function لزيادة عدد المشاهدات لمنتجات OCR
-- ==========================================
CREATE OR REPLACE FUNCTION increment_ocr_product_views(
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(UUID, TEXT) TO anon;

-- ==========================================
-- إضافة عمود المشاهدات لجدول الأدوات الجراحية
-- ==========================================

-- إضافة عمود views لجدول distributor_surgical_tools إذا لم يكن موجوداً
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'distributor_surgical_tools' AND column_name = 'views'
    ) THEN
        ALTER TABLE distributor_surgical_tools ADD COLUMN views INTEGER DEFAULT 0;
    END IF;
END $$;

-- إنشاء index على عمود views في distributor_surgical_tools
CREATE INDEX IF NOT EXISTS idx_distributor_surgical_tools_views ON distributor_surgical_tools(views DESC);

-- تحديث القيم الحالية إلى 0 إذا كانت null
UPDATE distributor_surgical_tools SET views = 0 WHERE views IS NULL;

-- إضافة constraint للتأكد من أن views لا تكون سالبة (إذا لم يكن موجوداً)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'distributor_surgical_tools' 
        AND constraint_name = 'check_surgical_views_non_negative'
    ) THEN
        ALTER TABLE distributor_surgical_tools 
        ADD CONSTRAINT check_surgical_views_non_negative 
        CHECK (views >= 0);
    END IF;
END $$;

-- ==========================================
-- Function لزيادة عدد المشاهدات للأدوات الجراحية
-- ==========================================
CREATE OR REPLACE FUNCTION increment_surgical_tool_views(tool_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE distributor_surgical_tools 
    SET views = COALESCE(views, 0) + 1 
    WHERE id = tool_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(UUID) TO anon;

-- ==========================================
-- تم بنجاح! ✅
-- ==========================================
