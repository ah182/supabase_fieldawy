-- ===================================================
-- Analytics Functions for Dashboard - FIXED VERSION
-- دوال التحليلات للوحة التحكم - النسخة المصححة
-- ===================================================

-- Function to get trending catalog products across all distributors
-- دالة للحصول على المنتجات الرائجة من الكتالوج عبر جميع الموزعين
CREATE OR REPLACE FUNCTION get_trending_catalog_products()
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    total_views BIGINT,
    distributor_count BIGINT,
    growth_percentage NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dp.product_id,
        p.name as product_name,
        SUM(dp.views) as total_views,
        COUNT(DISTINCT dp.distributor_id) as distributor_count,
        -- Calculate growth percentage (mock for now - would need historical data)
        CASE 
            WHEN SUM(dp.views) > 100 THEN 25.0
            WHEN SUM(dp.views) > 50 THEN 15.0
            ELSE 5.0
        END as growth_percentage
    FROM distributor_products dp
    JOIN products p ON dp.product_id = p.id
    WHERE dp.views > 0
    GROUP BY dp.product_id, p.name
    ORDER BY total_views DESC, distributor_count DESC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql;

-- Function to get trending OCR products across all distributors
-- دالة للحصول على منتجات OCR الرائجة عبر جميع الموزعين
CREATE OR REPLACE FUNCTION get_trending_ocr_products()
RETURNS TABLE (
    id UUID,
    product_name TEXT,
    total_views BIGINT,
    distributor_count BIGINT,
    growth_percentage NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dop.ocr_product_id as id,
        op.product_name,
        SUM(dop.views) as total_views,
        COUNT(DISTINCT dop.distributor_id) as distributor_count,
        -- Calculate growth percentage (mock for now)
        CASE 
            WHEN SUM(dop.views) > 80 THEN 30.0
            WHEN SUM(dop.views) > 40 THEN 20.0
            ELSE 10.0
        END as growth_percentage
    FROM distributor_ocr_products dop
    JOIN ocr_products op ON dop.ocr_product_id = op.id
    WHERE dop.views > 0
    GROUP BY dop.ocr_product_id, op.product_name
    ORDER BY total_views DESC, distributor_count DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- FIXED: Function to get category trends based on views
-- مصححة: دالة للحصول على اتجاهات الفئات بناءً على المشاهدات
CREATE OR REPLACE FUNCTION get_category_trends()
RETURNS TABLE (
    category_name TEXT,
    total_views BIGINT,
    product_count BIGINT,
    growth_percentage NUMERIC
) AS $$
BEGIN
    -- Since products table doesn't have category column,
    -- we'll create mock categories based on product types
    RETURN QUERY
    SELECT * FROM (VALUES
        ('مضادات حيوية', 450::BIGINT, 25::BIGINT, 45.0::NUMERIC),
        ('أدوية طوارئ', 320::BIGINT, 18::BIGINT, 30.0::NUMERIC),
        ('مكملات غذائية', 280::BIGINT, 15::BIGINT, 25.0::NUMERIC),
        ('أدوات جراحية', 220::BIGINT, 12::BIGINT, 15.0::NUMERIC),
        ('مستلزمات تشخيص', 180::BIGINT, 10::BIGINT, -10.0::NUMERIC),
        ('أدوية جلدية', 150::BIGINT, 8::BIGINT, -5.0::NUMERIC)
    ) AS t(category_name, total_views, product_count, growth_percentage)
    ORDER BY total_views DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get most searched keywords (mock function)
-- دالة للحصول على الكلمات الأكثر بحثاً (دالة تجريبية)
CREATE OR REPLACE FUNCTION get_search_trends()
RETURNS TABLE (
    keyword TEXT,
    search_count INTEGER
) AS $$
BEGIN
    -- This is a mock function since we don't track searches yet
    -- In real implementation, this would query a search_logs table
    RETURN QUERY
    SELECT * FROM (VALUES
        ('مضاد حيوي', 245),
        ('فيتامينات', 189),
        ('أدوية قطط', 156),
        ('حقن بيطرية', 134),
        ('علاج التهابات', 112),
        ('مسكنات ألم', 98),
        ('أدوية كلاب', 87),
        ('مطهرات جروح', 76)
    ) AS t(keyword, search_count)
    ORDER BY search_count DESC;
END;
$$ LANGUAGE plpgsql;

-- FIXED: Function to get user's product performance compared to global trends
-- مصححة: دالة للحصول على أداء منتجات المستخدم مقارنة بالاتجاهات العالمية
CREATE OR REPLACE FUNCTION get_user_vs_global_trends(user_id_param UUID)
RETURNS TABLE (
    has_trending_products INTEGER,
    missing_trending_count INTEGER,
    category_diversity_score INTEGER,
    recommendation_type TEXT,
    recommendation_text TEXT
) AS $$
DECLARE
    user_products_count INTEGER;
    user_categories_count INTEGER;
    trending_in_catalog INTEGER;
BEGIN
    -- Count user's total products from all sources
    SELECT 
        COALESCE(
            (SELECT COUNT(*) FROM distributor_products WHERE distributor_id = user_id_param), 0
        ) +
        COALESCE(
            (SELECT COUNT(*) FROM distributor_ocr_products WHERE distributor_id = user_id_param), 0
        ) +
        COALESCE(
            (SELECT COUNT(*) FROM distributor_surgical_tools WHERE distributor_id = user_id_param), 0
        ) +
        COALESCE(
            (SELECT COUNT(*) FROM vet_supplies WHERE user_id = user_id_param), 0
        )
    INTO user_products_count;
    
    -- Mock category diversity (since we don't have categories)
    user_categories_count := LEAST(user_products_count / 5, 8);
    
    -- Count how many trending products user has (simplified)
    SELECT LEAST(user_products_count / 10, 5) INTO trending_in_catalog;
    
    RETURN QUERY
    SELECT 
        trending_in_catalog as has_trending_products,
        GREATEST(0, 5 - trending_in_catalog) as missing_trending_count,
        user_categories_count as category_diversity_score,
        CASE 
            WHEN user_categories_count < 3 THEN 'category_diversity'
            WHEN trending_in_catalog < 3 THEN 'add_trending'
            WHEN user_products_count < 20 THEN 'expand_catalog'
            ELSE 'optimize_existing'
        END as recommendation_type,
        CASE 
            WHEN user_categories_count < 3 THEN 'نوع في فئات منتجاتك لزيادة فرص الظهور'
            WHEN trending_in_catalog < 3 THEN 'أضف المنتجات الرائجة عالمياً لكتالوجك'
            WHEN user_products_count < 20 THEN 'وسع كتالوجك بإضافة منتجات أكثر'
            ELSE 'ركز على تحسين منتجاتك الحالية'
        END as recommendation_text;
END;
$$ LANGUAGE plpgsql;

-- Function to get hourly views pattern for a user
-- دالة للحصول على نمط المشاهدات بالساعة للمستخدم
CREATE OR REPLACE FUNCTION get_user_hourly_views_pattern(user_id_param UUID)
RETURNS TABLE (
    hour_of_day INTEGER,
    avg_views NUMERIC,
    peak_indicator BOOLEAN
) AS $$
BEGIN
    -- This is a simplified version - in real implementation,
    -- you'd track view timestamps and analyze them
    RETURN QUERY
    SELECT 
        h.hour_val as hour_of_day,
        CASE 
            WHEN h.hour_val BETWEEN 9 AND 17 THEN 15.5  -- Business hours
            WHEN h.hour_val BETWEEN 18 AND 22 THEN 8.2  -- Evening
            ELSE 2.1  -- Night/early morning
        END as avg_views,
        CASE 
            WHEN h.hour_val BETWEEN 10 AND 16 THEN TRUE
            ELSE FALSE
        END as peak_indicator
    FROM generate_series(0, 23) AS h(hour_val)
    ORDER BY h.hour_val;
END;
$$ LANGUAGE plpgsql;

-- Drop the old functions if they exist to avoid conflicts
DROP FUNCTION IF EXISTS get_trending_catalog_products();
DROP FUNCTION IF EXISTS get_trending_ocr_products();
DROP FUNCTION IF EXISTS get_category_trends();
DROP FUNCTION IF EXISTS get_search_trends();
DROP FUNCTION IF EXISTS get_user_vs_global_trends(UUID);
DROP FUNCTION IF EXISTS get_user_hourly_views_pattern(UUID);

-- Recreate the functions with the fixed versions above
-- (The functions are already defined above, this is just for clarity)

-- Grant permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_trending_catalog_products() TO authenticated;
GRANT EXECUTE ON FUNCTION get_trending_ocr_products() TO authenticated;
GRANT EXECUTE ON FUNCTION get_category_trends() TO authenticated;
GRANT EXECUTE ON FUNCTION get_search_trends() TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_vs_global_trends(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_hourly_views_pattern(UUID) TO authenticated;

-- Create indexes to improve performance
CREATE INDEX IF NOT EXISTS idx_distributor_products_views_product 
ON distributor_products(product_id, views);

CREATE INDEX IF NOT EXISTS idx_distributor_ocr_products_views_product 
ON distributor_ocr_products(ocr_product_id, views);

-- Example usage comments
/*
-- Get trending catalog products:
SELECT * FROM get_trending_catalog_products();

-- Get trending OCR products:
SELECT * FROM get_trending_ocr_products();

-- Get category trends (now with mock data):
SELECT * FROM get_category_trends();

-- Get search trends:
SELECT * FROM get_search_trends();

-- Get user analysis:
SELECT * FROM get_user_vs_global_trends('your-user-id-here');

-- Get user hourly pattern:
SELECT * FROM get_user_hourly_views_pattern('your-user-id-here');
*/