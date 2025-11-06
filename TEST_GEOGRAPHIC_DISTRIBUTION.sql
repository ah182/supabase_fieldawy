-- =====================================================
-- اختبار التوزيع الجغرافي للمشاهدات
-- =====================================================

-- 1. عرض جميع المشاهدات مع معلومات المستخدم
SELECT 
  pv.product_id,
  pv.product_type,
  pv.user_id,
  u.governorates,
  pv.viewed_at
FROM product_views pv
LEFT JOIN users u ON pv.user_id = u.id
ORDER BY pv.viewed_at DESC
LIMIT 20;

-- 2. التوزيع الجغرافي - عدد المشاهدات لكل محافظة
SELECT 
  jsonb_array_elements_text(u.governorates) as governorate,
  COUNT(*) as total_views,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM product_views pv
JOIN users u ON pv.user_id = u.id
WHERE u.governorates IS NOT NULL
GROUP BY governorate
ORDER BY total_views DESC;

-- 3. أكثر 5 محافظات مشاهدة
SELECT 
  jsonb_array_elements_text(u.governorates) as governorate,
  COUNT(*) as views
FROM product_views pv
JOIN users u ON pv.user_id = u.id
WHERE u.governorates IS NOT NULL
GROUP BY governorate
ORDER BY views DESC
LIMIT 5;

-- 4. المشاهدات حسب نوع المنتج والمحافظة
SELECT 
  pv.product_type,
  jsonb_array_elements_text(u.governorates) as governorate,
  COUNT(*) as views
FROM product_views pv
JOIN users u ON pv.user_id = u.id
WHERE u.governorates IS NOT NULL
GROUP BY pv.product_type, governorate
ORDER BY views DESC
LIMIT 20;

-- 5. إحصائيات عامة
SELECT 
  COUNT(*) as total_views,
  COUNT(DISTINCT user_id) as unique_users,
  COUNT(DISTINCT product_id) as unique_products,
  COUNT(DISTINCT product_type) as product_types
FROM product_views;

-- 6. المشاهدات حسب الدور والمحافظة
SELECT 
  pv.user_role,
  jsonb_array_elements_text(u.governorates) as governorate,
  COUNT(*) as views
FROM product_views pv
JOIN users u ON pv.user_id = u.id
WHERE u.governorates IS NOT NULL
GROUP BY pv.user_role, governorate
ORDER BY views DESC
LIMIT 20;

-- 7. المستخدمين الذين ليس لديهم governorates
SELECT 
  COUNT(*) as users_without_governorates
FROM product_views pv
LEFT JOIN users u ON pv.user_id = u.id
WHERE pv.user_id IS NOT NULL 
AND (u.governorates IS NULL OR u.governorates = '[]'::jsonb);

-- 8. نسبة التغطية الجغرافية
SELECT 
  COUNT(DISTINCT CASE WHEN u.governorates IS NOT NULL AND u.governorates != '[]'::jsonb THEN pv.user_id END) as users_with_location,
  COUNT(DISTINCT pv.user_id) as total_users,
  ROUND(
    COUNT(DISTINCT CASE WHEN u.governorates IS NOT NULL AND u.governorates != '[]'::jsonb THEN pv.user_id END) * 100.0 / 
    NULLIF(COUNT(DISTINCT pv.user_id), 0), 
    2
  ) as coverage_percentage
FROM product_views pv
LEFT JOIN users u ON pv.user_id = u.id
WHERE pv.user_id IS NOT NULL;

-- 9. المشاهدات اليوم حسب المحافظة
SELECT 
  jsonb_array_elements_text(u.governorates) as governorate,
  COUNT(*) as today_views
FROM product_views pv
JOIN users u ON pv.user_id = u.id
WHERE u.governorates IS NOT NULL
AND DATE(pv.viewed_at) = CURRENT_DATE
GROUP BY governorate
ORDER BY today_views DESC;

-- 10. المشاهدات هذا الأسبوع حسب المحافظة
SELECT 
  jsonb_array_elements_text(u.governorates) as governorate,
  COUNT(*) as week_views
FROM product_views pv
JOIN users u ON pv.user_id = u.id
WHERE u.governorates IS NOT NULL
AND pv.viewed_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY governorate
ORDER BY week_views DESC;

