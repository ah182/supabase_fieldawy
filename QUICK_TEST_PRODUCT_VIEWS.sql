-- =====================================================
-- اختبار سريع لنظام تتبع المشاهدات
-- =====================================================

-- =====================================================
-- 1. التحقق من وجود عمود views في الجداول
-- =====================================================
SELECT 
  table_name,
  column_name,
  data_type,
  column_default
FROM information_schema.columns
WHERE table_name IN (
  'distributor_products',
  'distributor_ocr_products',
  'distributor_surgical_tools',
  'offers',
  'courses',
  'books'
)
AND column_name = 'views'
ORDER BY table_name;

-- النتيجة المتوقعة: 4-6 صفوف (حسب الجداول الموجودة)

-- =====================================================
-- 2. التحقق من وجود جدول product_views
-- =====================================================
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'product_views'
ORDER BY ordinal_position;

-- النتيجة المتوقعة: 5 أعمدة (id, product_id, user_id, user_role, product_type, viewed_at)

-- =====================================================
-- 3. التحقق من وجود Functions
-- =====================================================
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE '%track%view%'
ORDER BY routine_name;

-- النتيجة المتوقعة: 7 functions

-- =====================================================
-- 4. التحقق من RLS Policies
-- =====================================================
SELECT 
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'product_views';

-- النتيجة المتوقعة: 2 policies (insert, select)

-- =====================================================
-- 5. اختبار تسجيل المشاهدات
-- =====================================================

-- اختبار 1: منتج عادي
SELECT track_product_view('test-regular-001', 'regular');

-- اختبار 2: منتج OCR
SELECT track_product_view('test-ocr-002', 'ocr');

-- اختبار 3: أداة جراحية
SELECT track_product_view('test-surgical-003', 'surgical');

-- اختبار 4: عرض
SELECT track_product_view('test-offer-004', 'offer');

-- اختبار 5: كورس
SELECT track_product_view('test-course-005', 'course');

-- اختبار 6: كتاب
SELECT track_product_view('test-book-006', 'book');

-- =====================================================
-- 6. التحقق من البيانات المسجلة
-- =====================================================
SELECT 
  product_id,
  product_type,
  user_role,
  viewed_at
FROM product_views
WHERE product_id LIKE 'test-%'
ORDER BY viewed_at DESC;

-- النتيجة المتوقعة: 6 صفوف

-- =====================================================
-- 7. عدد المشاهدات حسب النوع
-- =====================================================
SELECT 
  product_type,
  COUNT(*) as total_views
FROM product_views
GROUP BY product_type
ORDER BY total_views DESC;

-- =====================================================
-- 8. آخر 10 مشاهدات
-- =====================================================
SELECT 
  product_id,
  product_type,
  user_role,
  viewed_at
FROM product_views
ORDER BY viewed_at DESC
LIMIT 10;

-- =====================================================
-- 9. اختبار Functions المساعدة
-- =====================================================

-- منتج عادي
SELECT track_regular_product_view('helper-regular-001');

-- منتج OCR
SELECT track_ocr_product_view('helper-ocr-002');

-- أداة جراحية
SELECT track_surgical_tool_view('helper-surgical-003');

-- عرض
SELECT track_offer_view('helper-offer-004');

-- كورس
SELECT track_course_view('helper-course-005');

-- كتاب
SELECT track_book_view('helper-book-006');

-- التحقق
SELECT 
  product_id,
  product_type
FROM product_views
WHERE product_id LIKE 'helper-%'
ORDER BY viewed_at DESC;

-- النتيجة المتوقعة: 6 صفوف إضافية

-- =====================================================
-- 10. تنظيف بيانات الاختبار (اختياري)
-- =====================================================
-- DELETE FROM product_views WHERE product_id LIKE 'test-%';
-- DELETE FROM product_views WHERE product_id LIKE 'helper-%';

-- =====================================================
-- 11. إحصائيات عامة
-- =====================================================

-- إجمالي المشاهدات
SELECT COUNT(*) as total_views FROM product_views;

-- المشاهدات حسب الدور
SELECT 
  COALESCE(user_role, 'guest') as role,
  COUNT(*) as views
FROM product_views
GROUP BY user_role
ORDER BY views DESC;

-- المشاهدات اليوم
SELECT COUNT(*) as today_views
FROM product_views
WHERE DATE(viewed_at) = CURRENT_DATE;

-- المشاهدات هذا الأسبوع
SELECT COUNT(*) as week_views
FROM product_views
WHERE viewed_at >= CURRENT_DATE - INTERVAL '7 days';

-- المشاهدات هذا الشهر
SELECT COUNT(*) as month_views
FROM product_views
WHERE viewed_at >= CURRENT_DATE - INTERVAL '30 days';

-- =====================================================
-- ✅ إذا نجحت جميع الاستعلامات، فالنظام يعمل بشكل صحيح!
-- =====================================================

