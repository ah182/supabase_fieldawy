-- ===================================================
-- Complete Dashboard Schema Fix - إصلاح مخطط لوحة التحكم الكامل
-- ===================================================
-- This migration includes ALL distributor product tables:
-- - distributor_products (catalog products)
-- - distributor_ocr_products (OCR products)  
-- - distributor_surgical_tools (surgical tools)
-- - vet_supplies (vet supplies)
-- - offers (limited offers)

-- ===================================================
-- 1. Add missing columns to existing tables if needed
-- إضافة الأعمدة المفقودة للجداول الموجودة إذا لزم الأمر
-- ===================================================

-- Add views column to distributor_products if not exists
-- إضافة عمود المشاهدات لجدول منتجات الموزعين من الكتالوج
ALTER TABLE distributor_products 
ADD COLUMN IF NOT EXISTS views INTEGER DEFAULT 0;

-- Add views column to distributor_ocr_products if not exists
-- إضافة عمود المشاهدات لجدول منتجات الموزعين OCR إذا لم يكن موجوداً
ALTER TABLE distributor_ocr_products 
ADD COLUMN IF NOT EXISTS views INTEGER DEFAULT 0;

-- Add views column to distributor_surgical_tools if not exists  
-- إضافة عمود المشاهدات لجدول الأدوات الجراحية للموزعين إذا لم يكن موجوداً
ALTER TABLE distributor_surgical_tools 
ADD COLUMN IF NOT EXISTS views INTEGER DEFAULT 0;

-- Add views column to vet_supplies if not exists
-- إضافة عمود المشاهدات لجدول المستلزمات البيطرية إذا لم يكن موجوداً  
ALTER TABLE vet_supplies 
ADD COLUMN IF NOT EXISTS views INTEGER DEFAULT 0;

-- ===================================================
-- 2. Create indexes for better performance
-- إنشاء فهارس لتحسين الأداء
-- ===================================================

-- Indexes for distributor_products
CREATE INDEX IF NOT EXISTS idx_distributor_products_views 
ON distributor_products(views);

CREATE INDEX IF NOT EXISTS idx_distributor_products_added_at 
ON distributor_products(added_at DESC);

CREATE INDEX IF NOT EXISTS idx_distributor_products_distributor_views 
ON distributor_products(distributor_id, views);

CREATE INDEX IF NOT EXISTS idx_distributor_products_distributor_added 
ON distributor_products(distributor_id, added_at);

-- Indexes for distributor_ocr_products
CREATE INDEX IF NOT EXISTS idx_distributor_ocr_products_views 
ON distributor_ocr_products(views);

CREATE INDEX IF NOT EXISTS idx_distributor_ocr_products_created_at 
ON distributor_ocr_products(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_distributor_ocr_products_distributor_views 
ON distributor_ocr_products(distributor_id, views);

-- Indexes for distributor_surgical_tools  
CREATE INDEX IF NOT EXISTS idx_distributor_surgical_tools_views 
ON distributor_surgical_tools(views);

CREATE INDEX IF NOT EXISTS idx_distributor_surgical_tools_distributor_views 
ON distributor_surgical_tools(distributor_id, views);

-- Indexes for vet_supplies
CREATE INDEX IF NOT EXISTS idx_vet_supplies_views 
ON vet_supplies(views);

CREATE INDEX IF NOT EXISTS idx_vet_supplies_user_views 
ON vet_supplies(user_id, views);

-- Indexes for offers (already has views column)
CREATE INDEX IF NOT EXISTS idx_offers_user_views 
ON offers(user_id, views);

-- ===================================================
-- 3. Functions to increment views for all tables
-- دوال لزيادة عدد المشاهدات لجميع الجداول
-- ===================================================

-- Function to increment distributor product views
-- دالة لزيادة مشاهدات منتجات الموزعين من الكتالوج
CREATE OR REPLACE FUNCTION increment_distributor_product_views(p_product_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE distributor_products 
    SET views = COALESCE(views, 0) + 1
    WHERE id = p_product_id;
END;
$$ LANGUAGE plpgsql;

-- Function to increment OCR product views
-- دالة لزيادة مشاهدات منتجات OCR
CREATE OR REPLACE FUNCTION increment_ocr_product_views(p_product_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE distributor_ocr_products 
    SET views = COALESCE(views, 0) + 1
    WHERE id = p_product_id;
END;
$$ LANGUAGE plpgsql;

-- Function to increment surgical tool views  
-- دالة لزيادة مشاهدات الأدوات الجراحية
CREATE OR REPLACE FUNCTION increment_surgical_tool_views(p_tool_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE distributor_surgical_tools 
    SET views = COALESCE(views, 0) + 1
    WHERE id = p_tool_id;
END;
$$ LANGUAGE plpgsql;

-- Function to increment vet supply views
-- دالة لزيادة مشاهدات المستلزمات البيطرية  
CREATE OR REPLACE FUNCTION increment_vet_supply_views(p_supply_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE vet_supplies 
    SET views = COALESCE(views, 0) + 1
    WHERE id = p_supply_id;
END;
$$ LANGUAGE plpgsql;

-- ===================================================
-- 4. Enhanced dashboard statistics function
-- دالة إحصائيات لوحة التحكم المحسنة
-- ===================================================

-- Function to get comprehensive dashboard stats for a user
-- دالة للحصول على إحصائيات شاملة للوحة التحكم للمستخدم
CREATE OR REPLACE FUNCTION get_complete_dashboard_stats(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
    stats JSON;
BEGIN
    SELECT json_build_object(
        -- Product counts from all sources
        'total_catalog_products', (SELECT COUNT(*) FROM distributor_products WHERE distributor_id = p_user_id),
        'total_ocr_products', (SELECT COUNT(*) FROM distributor_ocr_products WHERE distributor_id = p_user_id),
        'total_surgical_tools', (SELECT COUNT(*) FROM distributor_surgical_tools WHERE distributor_id = p_user_id),
        'total_vet_supplies', (SELECT COUNT(*) FROM vet_supplies WHERE user_id = p_user_id),
        
        -- Offers
        'active_offers', (SELECT COUNT(*) FROM offers WHERE user_id = p_user_id AND expiration_date > NOW()),
        'total_offers', (SELECT COUNT(*) FROM offers WHERE user_id = p_user_id),
        
        -- Views from all sources
        'total_views_catalog', (SELECT COALESCE(SUM(views), 0) FROM distributor_products WHERE distributor_id = p_user_id),
        'total_views_ocr', (SELECT COALESCE(SUM(views), 0) FROM distributor_ocr_products WHERE distributor_id = p_user_id),
        'total_views_surgical', (SELECT COALESCE(SUM(views), 0) FROM distributor_surgical_tools WHERE distributor_id = p_user_id),
        'total_views_vet', (SELECT COALESCE(SUM(views), 0) FROM vet_supplies WHERE user_id = p_user_id),
        'total_views_offers', (SELECT COALESCE(SUM(views), 0) FROM offers WHERE user_id = p_user_id),
        
        -- Monthly growth calculations
        'this_month_catalog', (
            SELECT COUNT(*) FROM distributor_products 
            WHERE distributor_id = p_user_id 
            AND added_at >= date_trunc('month', CURRENT_DATE)
        ),
        'this_month_ocr', (
            SELECT COUNT(*) FROM distributor_ocr_products 
            WHERE distributor_id = p_user_id 
            AND created_at >= date_trunc('month', CURRENT_DATE)
        ),
        'last_month_catalog', (
            SELECT COUNT(*) FROM distributor_products 
            WHERE distributor_id = p_user_id 
            AND added_at >= date_trunc('month', CURRENT_DATE) - INTERVAL '1 month'
            AND added_at < date_trunc('month', CURRENT_DATE)
        ),
        'last_month_ocr', (
            SELECT COUNT(*) FROM distributor_ocr_products 
            WHERE distributor_id = p_user_id 
            AND created_at >= date_trunc('month', CURRENT_DATE) - INTERVAL '1 month'
            AND created_at < date_trunc('month', CURRENT_DATE)
        )
    ) INTO stats;
    
    RETURN stats;
END;
$$ LANGUAGE plpgsql;

-- ===================================================
-- 5. Update existing records to have 0 views
-- تحديث السجلات الموجودة لتبدأ بـ 0 مشاهدات
-- ===================================================

-- Update distributor products
UPDATE distributor_products SET views = 0 WHERE views IS NULL;

-- Update OCR products
UPDATE distributor_ocr_products SET views = 0 WHERE views IS NULL;

-- Update surgical tools  
UPDATE distributor_surgical_tools SET views = 0 WHERE views IS NULL;

-- Update vet supplies
UPDATE vet_supplies SET views = 0 WHERE views IS NULL;

-- Update offers (already handled in previous migration)
UPDATE offers SET views = 0 WHERE views IS NULL;

-- ===================================================
-- 6. Create views for easier dashboard queries
-- إنشاء views لاستعلامات لوحة التحكم الأسهل
-- ===================================================

-- View for all distributor products combined
-- عرض لجميع منتجات الموزع مجمعة
CREATE OR REPLACE VIEW distributor_all_products AS
SELECT 
    dp.id,
    dp.distributor_id,
    p.name as product_name,
    dp.price,
    dp.package,
    dp.added_at as created_at,
    dp.views,
    'catalog' as source_type
FROM distributor_products dp
JOIN products p ON dp.product_id = p.id

UNION ALL

SELECT 
    dop.id::text as id,
    dop.distributor_id,
    op.product_name,
    dop.price,
    'N/A' as package,
    dop.created_at,
    dop.views,
    'ocr' as source_type
FROM distributor_ocr_products dop
JOIN ocr_products op ON dop.ocr_product_id = op.id;

-- ===================================================
-- 7. Grant necessary permissions
-- منح الصلاحيات الضرورية
-- ===================================================

-- Grant execute permissions on new functions
GRANT EXECUTE ON FUNCTION increment_distributor_product_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_vet_supply_views(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_complete_dashboard_stats(UUID) TO authenticated;

-- Grant select permissions on the new view
GRANT SELECT ON distributor_all_products TO authenticated;