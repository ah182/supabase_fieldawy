-- ============================================
-- DROP Unused Views
-- ============================================
-- هذا الملف لحذف الـ views غير المستخدمة

-- ⚠️ تحذير: قبل الحذف، تأكد إن الـ views مش مستخدمة في الكود!

-- حذف view واحد (مثال)
-- DROP VIEW IF EXISTS view_name CASCADE;

-- حذف كل review views (إزالة التعليق لو عايز تحذفهم)
/*
DROP VIEW IF EXISTS 
  review_requests_with_details,
  active_review_requests,
  my_review_requests,
  product_reviews_with_details,
  my_product_reviews
CASCADE;
*/

-- حذف notification stats view (إزالة التعليق لو عايز تحذفه)
/*
DROP VIEW IF EXISTS notification_stats CASCADE;
*/

-- ============================================
-- عشان تشغل الملف ده:
-- 1. روح Supabase Dashboard → SQL Editor
-- 2. انسخ الأمر اللي عايزه فوق (بعد إزالة التعليق /*)
-- 3. اضغط Run
-- ============================================
