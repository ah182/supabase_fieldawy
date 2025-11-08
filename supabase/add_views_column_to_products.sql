-- إضافة عمود views لجدول products وحساب المجموع من جميع الموزعين
-- Add views column to products table and calculate total from all distributors

-- 1. إضافة عمود views إلى جدول products
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS views BIGINT DEFAULT 0;

-- 2. إنشاء دالة لحساب وتحديث مجموع المشاهدات للمنتج
CREATE OR REPLACE FUNCTION update_product_total_views(p_product_id TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_views BIGINT := 0;
BEGIN
    -- حساب مجموع المشاهدات من جميع جداول الموزعين
    
    -- من جدول distributor_products
    SELECT COALESCE(SUM(views), 0) INTO total_views
    FROM distributor_products
    WHERE product_id = p_product_id;
    
    -- تحديث العمود في جدول products (كلاهما TEXT)
    UPDATE products 
    SET views = total_views
    WHERE id = p_product_id;
    
    RAISE NOTICE 'Updated product % views to %', p_product_id, total_views;
END;
$$;

-- 3. إنشاء دالة لتحديث جميع المنتجات (للتشغيل الأولي)
CREATE OR REPLACE FUNCTION update_all_products_views()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    product_text TEXT;
    total_updated INTEGER := 0;
BEGIN
    RAISE NOTICE 'Starting to update views for all products...';
    
    -- تحديث جميع المنتجات الموجودة في جدول distributor_products
    FOR product_text IN 
        SELECT DISTINCT dp.product_id
        FROM distributor_products dp
        WHERE dp.product_id IS NOT NULL AND dp.product_id != ''
    LOOP
        PERFORM update_product_total_views(product_text);
        total_updated := total_updated + 1;
    END LOOP;
    
    RAISE NOTICE 'Updated views for % products', total_updated;
END;
$$;

-- 4. إنشاء trigger لتحديث المشاهدات تلقائياً عند تغيير جدول distributor_products
CREATE OR REPLACE FUNCTION trigger_update_product_views()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- تحديث المشاهدات للمنتج المتأثر
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        PERFORM update_product_total_views(NEW.product_id);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM update_product_total_views(OLD.product_id);
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$;

-- 5. إنشاء trigger على جدول distributor_products
DROP TRIGGER IF EXISTS update_product_views_trigger ON distributor_products;
CREATE TRIGGER update_product_views_trigger
    AFTER INSERT OR UPDATE OR DELETE ON distributor_products
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_product_views();

-- 6. تشغيل التحديث الأولي لجميع المنتجات
SELECT update_all_products_views();

-- 7. إنشاء فهرس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_products_views ON products(views DESC);
CREATE INDEX IF NOT EXISTS idx_distributor_products_views ON distributor_products(product_id, views);

-- 8. دالة لحساب أشهر المنتجات (للاستخدام في التوصيات)
CREATE OR REPLACE FUNCTION get_top_viewed_products(
    exclude_user_id UUID DEFAULT NULL,
    limit_count INTEGER DEFAULT 20
)
RETURNS TABLE (
    id TEXT,
    name TEXT,
    views BIGINT,
    distributor_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        p.views,
        COUNT(DISTINCT dp.distributor_id) as distributor_count
    FROM products p
    LEFT JOIN distributor_products dp ON p.id = dp.product_id
    WHERE (exclude_user_id IS NULL OR p.id NOT IN (
        SELECT product_id 
        FROM distributor_products 
        WHERE distributor_id = exclude_user_id
    ))
    GROUP BY p.id, p.name, p.views
    ORDER BY p.views DESC, distributor_count DESC
    LIMIT limit_count;
END;
$$;

-- 9. منح الصلاحيات اللازمة
GRANT EXECUTE ON FUNCTION update_product_total_views TO authenticated;
GRANT EXECUTE ON FUNCTION update_all_products_views TO authenticated;
GRANT EXECUTE ON FUNCTION get_top_viewed_products TO authenticated;

-- 10. عرض النتائج
SELECT 
    COUNT(*) as total_products,
    COUNT(CASE WHEN views > 0 THEN 1 END) as products_with_views,
    MAX(views) as max_views,
    AVG(views) as avg_views
FROM products;

-- 11. عرض رسالة النجاح
SELECT 'Products views column setup completed successfully!' as status;
SELECT 'Use get_top_viewed_products() function to get top products excluding user products' as usage_info;
SELECT 'Views will be automatically updated when distributor_products table changes' as auto_update_info;