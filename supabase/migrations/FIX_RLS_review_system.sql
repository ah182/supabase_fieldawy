-- ============================================================================
-- FIX RLS: Review System
-- Date: 2025-01-23
-- Description: إصلاح مشاكل RLS وإعادة التطبيق
-- ============================================================================

-- 📌 استخدم هذا الملف إذا كان RLS لا يعمل بشكل صحيح

-- ============================================================================
-- الخطوة 1: تعطيل RLS مؤقتاً (للإصلاح)
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '⏳ Disabling RLS temporarily...';
END $$;

ALTER TABLE public.review_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_reviews DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_helpful_votes DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- الخطوة 2: حذف جميع الـ Policies القديمة
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '🗑️  Removing old policies...';
END $$;

-- review_requests
DROP POLICY IF EXISTS review_requests_select_all ON public.review_requests;
DROP POLICY IF EXISTS review_requests_select_authenticated ON public.review_requests;
DROP POLICY IF EXISTS review_requests_select_anon ON public.review_requests;
DROP POLICY IF EXISTS review_requests_insert_authenticated ON public.review_requests;
DROP POLICY IF EXISTS review_requests_update_owner ON public.review_requests;
DROP POLICY IF EXISTS review_requests_delete_owner ON public.review_requests;

-- product_reviews
DROP POLICY IF EXISTS product_reviews_select_all ON public.product_reviews;
DROP POLICY IF EXISTS product_reviews_select_authenticated ON public.product_reviews;
DROP POLICY IF EXISTS product_reviews_select_anon ON public.product_reviews;
DROP POLICY IF EXISTS product_reviews_insert_authenticated ON public.product_reviews;
DROP POLICY IF EXISTS product_reviews_update_owner ON public.product_reviews;
DROP POLICY IF EXISTS product_reviews_delete_owner ON public.product_reviews;

-- review_helpful_votes
DROP POLICY IF EXISTS review_helpful_votes_select_all ON public.review_helpful_votes;
DROP POLICY IF EXISTS review_helpful_votes_select_authenticated ON public.review_helpful_votes;
DROP POLICY IF EXISTS review_helpful_votes_select_anon ON public.review_helpful_votes;
DROP POLICY IF EXISTS review_helpful_votes_insert_authenticated ON public.review_helpful_votes;
DROP POLICY IF EXISTS review_helpful_votes_update_owner ON public.review_helpful_votes;
DROP POLICY IF EXISTS review_helpful_votes_delete_owner ON public.review_helpful_votes;

-- ============================================================================
-- الخطوة 3: إعادة تفعيل RLS
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '🔒 Re-enabling RLS...';
END $$;

ALTER TABLE public.review_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_helpful_votes ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- الخطوة 4: إنشاء الـ Policies الجديدة
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✨ Creating new policies...';
END $$;

-- ============================================================================
-- review_requests POLICIES
-- ============================================================================

-- SELECT: المستخدمون المسجلون
CREATE POLICY review_requests_select_authenticated
  ON public.review_requests
  FOR SELECT
  TO authenticated
  USING (true);

-- SELECT: الزوار (الطلبات النشطة فقط)
CREATE POLICY review_requests_select_anon
  ON public.review_requests
  FOR SELECT
  TO anon
  USING (status = 'active');

-- INSERT: المستخدم المصادق
CREATE POLICY review_requests_insert_authenticated
  ON public.review_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (requested_by = auth.uid());

-- UPDATE: صاحب الطلب فقط
CREATE POLICY review_requests_update_owner
  ON public.review_requests
  FOR UPDATE
  TO authenticated
  USING (requested_by = auth.uid())
  WITH CHECK (requested_by = auth.uid());

-- DELETE: صاحب الطلب فقط
CREATE POLICY review_requests_delete_owner
  ON public.review_requests
  FOR DELETE
  TO authenticated
  USING (requested_by = auth.uid());

-- ============================================================================
-- product_reviews POLICIES
-- ============================================================================

-- SELECT: المستخدمون المسجلون
CREATE POLICY product_reviews_select_authenticated
  ON public.product_reviews
  FOR SELECT
  TO authenticated
  USING (true);

-- SELECT: الزوار (جميع التقييمات عامة)
CREATE POLICY product_reviews_select_anon
  ON public.product_reviews
  FOR SELECT
  TO anon
  USING (true);

-- INSERT: المستخدم المصادق
CREATE POLICY product_reviews_insert_authenticated
  ON public.product_reviews
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- UPDATE: صاحب التقييم فقط
CREATE POLICY product_reviews_update_owner
  ON public.product_reviews
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- DELETE: صاحب التقييم فقط
CREATE POLICY product_reviews_delete_owner
  ON public.product_reviews
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- ============================================================================
-- review_helpful_votes POLICIES
-- ============================================================================

-- SELECT: المستخدمون المسجلون
CREATE POLICY review_helpful_votes_select_authenticated
  ON public.review_helpful_votes
  FOR SELECT
  TO authenticated
  USING (true);

-- SELECT: الزوار
CREATE POLICY review_helpful_votes_select_anon
  ON public.review_helpful_votes
  FOR SELECT
  TO anon
  USING (true);

-- INSERT: المستخدم المصادق
CREATE POLICY review_helpful_votes_insert_authenticated
  ON public.review_helpful_votes
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- UPDATE: صاحب التصويت فقط
CREATE POLICY review_helpful_votes_update_owner
  ON public.review_helpful_votes
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- DELETE: صاحب التصويت فقط
CREATE POLICY review_helpful_votes_delete_owner
  ON public.review_helpful_votes
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- ============================================================================
-- الخطوة 5: التحقق من النتيجة
-- ============================================================================

DO $$
DECLARE
  v_total_policies int;
  v_rls_enabled_count int;
BEGIN
  -- عد الـ policies
  SELECT COUNT(*) INTO v_total_policies
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN ('review_requests', 'product_reviews', 'review_helpful_votes');
  
  -- عد الجداول مع RLS
  SELECT COUNT(*) INTO v_rls_enabled_count
  FROM pg_tables t
  JOIN pg_class c ON c.relname = t.tablename AND c.relnamespace = t.schemaname::regnamespace
  WHERE t.schemaname = 'public'
    AND t.tablename IN ('review_requests', 'product_reviews', 'review_helpful_votes')
    AND c.relrowsecurity = true;
  
  RAISE NOTICE '';
  RAISE NOTICE '╔════════════════════════════════════╗';
  RAISE NOTICE '║    RLS Fix Completed               ║';
  RAISE NOTICE '╠════════════════════════════════════╣';
  RAISE NOTICE '║ Tables with RLS: %/3              ║', v_rls_enabled_count;
  RAISE NOTICE '║ Total Policies: %                 ║', v_total_policies;
  RAISE NOTICE '╚════════════════════════════════════╝';
  RAISE NOTICE '';
  
  IF v_rls_enabled_count = 3 AND v_total_policies = 15 THEN
    RAISE NOTICE '✅ RLS successfully fixed and applied!';
    RAISE NOTICE '✅ All 3 tables are now protected';
    RAISE NOTICE '✅ All 15 policies are in place';
  ELSE
    RAISE WARNING '⚠️  Something might be wrong:';
    IF v_rls_enabled_count < 3 THEN
      RAISE WARNING '   - Not all tables have RLS enabled';
    END IF;
    IF v_total_policies < 15 THEN
      RAISE WARNING '   - Missing policies (expected 15, got %)', v_total_policies;
    END IF;
  END IF;
END $$;

-- ============================================================================
-- تفاصيل الـ Policies المطبقة
-- ============================================================================

SELECT 
  tablename,
  COUNT(*) as policies_count,
  string_agg(policyname, ', ' ORDER BY policyname) as policy_names
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('review_requests', 'product_reviews', 'review_helpful_votes')
GROUP BY tablename
ORDER BY tablename;
