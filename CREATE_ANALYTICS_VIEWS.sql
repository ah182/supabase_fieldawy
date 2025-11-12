-- ========================================
-- SQL Views للأناليتكس في الأدمن داش بورد
-- ========================================
-- قم بتشغيل هذا الـ SQL في Supabase SQL Editor

-- ========================================
-- 1. View لإحصائيات المستخدمين
-- ========================================
CREATE OR REPLACE VIEW user_activity_stats AS
SELECT 
    u.id AS user_id,
    COALESCE(u.full_name, u.email, 'Unknown') AS display_name,
    u.email,
    COALESCE(u.role, 'user') AS role,
    COALESCE(search_count.total, 0) AS total_searches,
    COALESCE(view_count.total, 0) AS total_views,
    COALESCE(product_count.total, 0) AS total_products,
    COALESCE(
        GREATEST(search_count.last_activity, view_count.last_activity),
        NOW()
    ) AS last_activity_at
FROM 
    users u
LEFT JOIN (
    -- عدد عمليات البحث
    SELECT 
        user_id,
        COUNT(*) AS total,
        MAX(searched_at) AS last_activity
    FROM search_tracking
    GROUP BY user_id
) search_count ON u.id = search_count.user_id
LEFT JOIN (
    -- عدد المشاهدات
    SELECT 
        user_id,
        COUNT(*) AS total,
        MAX(viewed_at) AS last_activity
    FROM product_views
    GROUP BY user_id
) view_count ON u.id = view_count.user_id
LEFT JOIN (
    -- عدد المنتجات (للموزعين)
    SELECT 
        distributor_id AS user_id,
        COUNT(DISTINCT id) AS total
    FROM products
    WHERE distributor_id IS NOT NULL
    GROUP BY distributor_id
) product_count ON u.id = product_count.user_id
WHERE u.id IS NOT NULL
ORDER BY (COALESCE(search_count.total, 0) + COALESCE(view_count.total, 0)) DESC;

-- ========================================
-- 2. View لإحصائيات المنتجات
-- ========================================
CREATE OR REPLACE VIEW product_performance_stats AS
SELECT 
    p.id AS product_id,
    p.name AS product_name,
    p.company,
    dist_products.price,
    dist_products.distributor_id,
    dist_products.distributor_name,
    COALESCE(view_stats.total_views, 0) AS total_views,
    COALESCE(view_stats.doctor_views, 0) AS doctor_views,
    view_stats.last_viewed_at,
    COALESCE(dist_products.distributor_count, 0) AS distributor_count
FROM 
    products p
LEFT JOIN (
    -- إحصائيات المشاهدات
    SELECT 
        product_id,
        COUNT(*) AS total_views,
        COUNT(*) FILTER (WHERE user_role = 'doctor') AS doctor_views,
        MAX(viewed_at) AS last_viewed_at
    FROM product_views
    GROUP BY product_id
) view_stats ON p.id = view_stats.product_id
LEFT JOIN (
    -- معلومات الموزعين والسعر
    SELECT 
        product_id,
        MIN(distributor_id) AS distributor_id,
        MIN(price) AS price,
        COUNT(DISTINCT distributor_id) AS distributor_count,
        STRING_AGG(DISTINCT distributor_id, ', ') AS distributor_name
    FROM products
    WHERE distributor_id IS NOT NULL
    GROUP BY product_id
) dist_products ON p.id = dist_products.product_id
WHERE p.id IS NOT NULL
ORDER BY COALESCE(view_stats.total_views, 0) DESC;

-- ========================================
-- 3. إعطاء صلاحيات القراءة
-- ========================================
-- إذا كنت تستخدم RLS (Row Level Security)
ALTER VIEW user_activity_stats OWNER TO postgres;
ALTER VIEW product_performance_stats OWNER TO postgres;

-- منح صلاحية القراءة للمستخدمين
GRANT SELECT ON user_activity_stats TO anon, authenticated;
GRANT SELECT ON product_performance_stats TO anon, authenticated;

-- ========================================
-- 4. اختبار Views
-- ========================================
-- اختبر أن الـ Views تعمل بشكل صحيح

-- اختبار Top 10 Users
SELECT * FROM user_activity_stats 
ORDER BY (total_searches + total_views) DESC 
LIMIT 10;

-- اختبار Top 10 Products
SELECT * FROM product_performance_stats 
ORDER BY total_views DESC 
LIMIT 10;

-- ========================================
-- ملاحظات مهمة:
-- ========================================
-- 1. تأكد من وجود الجداول التالية:
--    - users (id, full_name, email, role)
--    - search_tracking (user_id, searched_at)
--    - product_views (product_id, user_id, user_role, viewed_at)
--    - products (id, name, company, distributor_id)
--
-- 2. إذا كانت أسماء الأعمدة مختلفة، عدّل الـ SQL
--
-- 3. Views تُحدّث تلقائياً مع كل query
--
-- 4. إذا أردت performance أفضل، استخدم Materialized Views:
--    CREATE MATERIALIZED VIEW بدلاً من CREATE VIEW
--    لكن ستحتاج لتحديثها يدوياً: REFRESH MATERIALIZED VIEW view_name;
