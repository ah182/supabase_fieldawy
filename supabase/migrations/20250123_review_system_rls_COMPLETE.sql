-- ============================================================================
-- RLS Policies: Review System (COMPLETE)
-- Date: 2025-01-23
-- Description: سياسات أمان شاملة لنظام التقييمات
-- ============================================================================

-- ============================================================================
-- 0. تفعيل RLS على جميع الجداول
-- ============================================================================

ALTER TABLE public.review_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_helpful_votes ENABLE ROW LEVEL SECURITY;

-- ملاحظة: الـ Views لا تحتاج RLS لأنها تعتمد على أمان الجداول الأساسية

-- ============================================================================
-- 1. review_requests POLICIES
-- ============================================================================

-- حذف الـ policies القديمة إن وجدت
DROP POLICY IF EXISTS review_requests_select_all ON public.review_requests;
DROP POLICY IF EXISTS review_requests_select_authenticated ON public.review_requests;
DROP POLICY IF EXISTS review_requests_insert_authenticated ON public.review_requests;
DROP POLICY IF EXISTS review_requests_update_owner ON public.review_requests;
DROP POLICY IF EXISTS review_requests_delete_owner ON public.review_requests;

-- SELECT: الجميع (authenticated) يمكنهم القراءة
CREATE POLICY review_requests_select_authenticated
  ON public.review_requests
  FOR SELECT
  TO authenticated
  USING (true);

-- SELECT: للمستخدمين غير المسجلين (للقراءة العامة فقط)
CREATE POLICY review_requests_select_anon
  ON public.review_requests
  FOR SELECT
  TO anon
  USING (status = 'active'); -- فقط الطلبات النشطة

-- INSERT: المستخدم المصادق يمكنه إنشاء طلب
CREATE POLICY review_requests_insert_authenticated
  ON public.review_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (requested_by = auth.uid());

-- UPDATE: فقط صاحب الطلب يمكنه التعديل
CREATE POLICY review_requests_update_owner
  ON public.review_requests
  FOR UPDATE
  TO authenticated
  USING (requested_by = auth.uid())
  WITH CHECK (requested_by = auth.uid());

-- DELETE: فقط صاحب الطلب يمكنه الحذف
CREATE POLICY review_requests_delete_owner
  ON public.review_requests
  FOR DELETE
  TO authenticated
  USING (requested_by = auth.uid());

COMMENT ON POLICY review_requests_select_authenticated ON public.review_requests IS 'المستخدمون المسجلون يمكنهم قراءة جميع الطلبات';
COMMENT ON POLICY review_requests_select_anon ON public.review_requests IS 'الزوار يمكنهم قراءة الطلبات النشطة فقط';
COMMENT ON POLICY review_requests_insert_authenticated ON public.review_requests IS 'المستخدم يمكنه إنشاء طلب تقييم';
COMMENT ON POLICY review_requests_update_owner ON public.review_requests IS 'فقط صاحب الطلب يمكنه تعديله';
COMMENT ON POLICY review_requests_delete_owner ON public.review_requests IS 'فقط صاحب الطلب يمكنه حذفه';

-- ============================================================================
-- 2. product_reviews POLICIES
-- ============================================================================

-- حذف الـ policies القديمة إن وجدت
DROP POLICY IF EXISTS product_reviews_select_all ON public.product_reviews;
DROP POLICY IF EXISTS product_reviews_select_authenticated ON public.product_reviews;
DROP POLICY IF EXISTS product_reviews_insert_authenticated ON public.product_reviews;
DROP POLICY IF EXISTS product_reviews_update_owner ON public.product_reviews;
DROP POLICY IF EXISTS product_reviews_delete_owner ON public.product_reviews;

-- SELECT: الجميع (authenticated) يمكنهم القراءة
CREATE POLICY product_reviews_select_authenticated
  ON public.product_reviews
  FOR SELECT
  TO authenticated
  USING (true);

-- SELECT: للمستخدمين غير المسجلين (للقراءة العامة)
CREATE POLICY product_reviews_select_anon
  ON public.product_reviews
  FOR SELECT
  TO anon
  USING (true); -- جميع التقييمات عامة

-- INSERT: المستخدم المصادق يمكنه إضافة تقييم
CREATE POLICY product_reviews_insert_authenticated
  ON public.product_reviews
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- UPDATE: فقط صاحب التقييم يمكنه تعديله
CREATE POLICY product_reviews_update_owner
  ON public.product_reviews
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- DELETE: فقط صاحب التقييم يمكنه حذفه
CREATE POLICY product_reviews_delete_owner
  ON public.product_reviews
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

COMMENT ON POLICY product_reviews_select_authenticated ON public.product_reviews IS 'المستخدمون المسجلون يمكنهم قراءة جميع التقييمات';
COMMENT ON POLICY product_reviews_select_anon ON public.product_reviews IS 'الزوار يمكنهم قراءة جميع التقييمات';
COMMENT ON POLICY product_reviews_insert_authenticated ON public.product_reviews IS 'المستخدم يمكنه إضافة تقييم';
COMMENT ON POLICY product_reviews_update_owner ON public.product_reviews IS 'فقط صاحب التقييم يمكنه تعديله';
COMMENT ON POLICY product_reviews_delete_owner ON public.product_reviews IS 'فقط صاحب التقييم يمكنه حذفه';

-- ============================================================================
-- 3. review_helpful_votes POLICIES
-- ============================================================================

-- حذف الـ policies القديمة إن وجدت
DROP POLICY IF EXISTS review_helpful_votes_select_all ON public.review_helpful_votes;
DROP POLICY IF EXISTS review_helpful_votes_select_authenticated ON public.review_helpful_votes;
DROP POLICY IF EXISTS review_helpful_votes_insert_authenticated ON public.review_helpful_votes;
DROP POLICY IF EXISTS review_helpful_votes_update_owner ON public.review_helpful_votes;
DROP POLICY IF EXISTS review_helpful_votes_delete_owner ON public.review_helpful_votes;

-- SELECT: المستخدمون المسجلون يمكنهم القراءة
CREATE POLICY review_helpful_votes_select_authenticated
  ON public.review_helpful_votes
  FOR SELECT
  TO authenticated
  USING (true);

-- SELECT: للمستخدمين غير المسجلين (العدادات فقط)
CREATE POLICY review_helpful_votes_select_anon
  ON public.review_helpful_votes
  FOR SELECT
  TO anon
  USING (true); -- للعد فقط

-- INSERT: المستخدم المصادق يمكنه التصويت
CREATE POLICY review_helpful_votes_insert_authenticated
  ON public.review_helpful_votes
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- UPDATE: فقط صاحب التصويت يمكنه تعديله
CREATE POLICY review_helpful_votes_update_owner
  ON public.review_helpful_votes
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- DELETE: فقط صاحب التصويت يمكنه حذفه
CREATE POLICY review_helpful_votes_delete_owner
  ON public.review_helpful_votes
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

COMMENT ON POLICY review_helpful_votes_select_authenticated ON public.review_helpful_votes IS 'المستخدمون المسجلون يمكنهم قراءة التصويتات';
COMMENT ON POLICY review_helpful_votes_select_anon ON public.review_helpful_votes IS 'الزوار يمكنهم قراءة التصويتات';
COMMENT ON POLICY review_helpful_votes_insert_authenticated ON public.review_helpful_votes IS 'المستخدم يمكنه التصويت';
COMMENT ON POLICY review_helpful_votes_update_owner ON public.review_helpful_votes IS 'فقط صاحب التصويت يمكنه تعديله';
COMMENT ON POLICY review_helpful_votes_delete_owner ON public.review_helpful_votes IS 'فقط صاحب التصويت يمكنه حذفه';

-- ============================================================================
-- 4. التحقق من RLS (اختياري - للتأكد)
-- ============================================================================

-- التحقق من تفعيل RLS على الجداول
DO $$
DECLARE
  v_table_name text;
  v_rls_enabled boolean;
BEGIN
  FOR v_table_name IN 
    SELECT tablename 
    FROM pg_tables 
    WHERE schemaname = 'public' 
      AND tablename IN ('review_requests', 'product_reviews', 'review_helpful_votes')
  LOOP
    SELECT relrowsecurity INTO v_rls_enabled
    FROM pg_class
    WHERE relname = v_table_name
      AND relnamespace = 'public'::regnamespace;
    
    IF v_rls_enabled THEN
      RAISE NOTICE '✅ RLS enabled on: %', v_table_name;
    ELSE
      RAISE WARNING '❌ RLS NOT enabled on: %', v_table_name;
    END IF;
  END LOOP;
END $$;

-- عرض عدد الـ policies لكل جدول
DO $$
DECLARE
  v_count int;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '📊 Policies Summary:';
  
  SELECT COUNT(*) INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'review_requests';
  RAISE NOTICE '   review_requests: % policies', v_count;
  
  SELECT COUNT(*) INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'product_reviews';
  RAISE NOTICE '   product_reviews: % policies', v_count;
  
  SELECT COUNT(*) INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'review_helpful_votes';
  RAISE NOTICE '   review_helpful_votes: % policies', v_count;
END $$;

-- ============================================================================
-- 5. رسالة النجاح
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ RLS Policies created successfully for Review System!';
  RAISE NOTICE '🔒 All 3 tables secured with Row Level Security';
  RAISE NOTICE '👥 Policies for: authenticated users, anonymous users, and owners';
  RAISE NOTICE '📖 Views inherit security from base tables automatically';
END $$;
