-- ===================================================
-- Fix Dashboard Schema - إصلاح مخطط لوحة التحكم  
-- ===================================================
-- This migration fixes the database schema to support the dashboard functionality
-- يصلح هذا الترحيل مخطط قاعدة البيانات لدعم وظائف لوحة التحكم

-- ===================================================
-- 1. Add missing columns to existing tables if needed
-- إضافة الأعمدة المفقودة للجداول الموجودة إذا لزم الأمر
-- ===================================================

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
-- 3. Functions to increment views
-- دوال لزيادة عدد المشاهدات
-- ===================================================

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
-- 4. Dashboard statistics functions
-- دوال إحصائيات لوحة التحكم
-- ===================================================

-- Function to get comprehensive dashboard stats for a user
-- دالة للحصول على إحصائيات شاملة للوحة التحكم للمستخدم
CREATE OR REPLACE FUNCTION get_dashboard_stats(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
    stats JSON;
BEGIN
    SELECT json_build_object(
        'total_ocr_products', (SELECT COUNT(*) FROM distributor_ocr_products WHERE distributor_id = p_user_id),
        'total_surgical_tools', (SELECT COUNT(*) FROM distributor_surgical_tools WHERE distributor_id = p_user_id),
        'total_vet_supplies', (SELECT COUNT(*) FROM vet_supplies WHERE user_id = p_user_id),
        'active_offers', (SELECT COUNT(*) FROM offers WHERE user_id = p_user_id AND expiration_date > NOW()),
        'total_views_ocr', (SELECT COALESCE(SUM(views), 0) FROM distributor_ocr_products WHERE distributor_id = p_user_id),
        'total_views_surgical', (SELECT COALESCE(SUM(views), 0) FROM distributor_surgical_tools WHERE distributor_id = p_user_id),
        'total_views_vet', (SELECT COALESCE(SUM(views), 0) FROM vet_supplies WHERE user_id = p_user_id),
        'total_views_offers', (SELECT COALESCE(SUM(views), 0) FROM offers WHERE user_id = p_user_id)
    ) INTO stats;
    
    RETURN stats;
END;
$$ LANGUAGE plpgsql;

-- ===================================================
-- 5. Update existing records to have 0 views
-- تحديث السجلات الموجودة لتبدأ بـ 0 مشاهدات
-- ===================================================

-- Update OCR products
UPDATE distributor_ocr_products SET views = 0 WHERE views IS NULL;

-- Update surgical tools  
UPDATE distributor_surgical_tools SET views = 0 WHERE views IS NULL;

-- Update vet supplies
UPDATE vet_supplies SET views = 0 WHERE views IS NULL;

-- Update offers (already handled in previous migration)
UPDATE offers SET views = 0 WHERE views IS NULL;

-- ===================================================
-- 6. Grant necessary permissions
-- منح الصلاحيات الضرورية
-- ===================================================

-- Grant execute permissions on new functions
GRANT EXECUTE ON FUNCTION increment_ocr_product_views(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_surgical_tool_views(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_vet_supply_views(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_dashboard_stats(UUID) TO authenticated;