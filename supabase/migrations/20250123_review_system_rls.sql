-- ============================================================================
-- RLS Policies: Review System
-- Date: 2025-01-23
-- Description: سياسات الأمان لنظام التقييمات
-- ============================================================================

-- ============================================================================
-- 1. review_requests POLICIES
-- ============================================================================

-- SELECT: الجميع يمكنهم القراءة
CREATE POLICY review_requests_select_all
  ON public.review_requests
  FOR SELECT
  TO authenticated
  USING (true);

-- INSERT: المستخدم المصادق يمكنه إنشاء طلب
-- سيتم التحقق من القيود (weekly limit, unique product) في الـ Function
CREATE POLICY review_requests_insert_authenticated
  ON public.review_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (requested_by = auth.uid());

-- UPDATE: فقط صاحب الطلب يمكنه التعديل (محدود)
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

-- ============================================================================
-- 2. product_reviews POLICIES
-- ============================================================================

-- SELECT: الجميع يمكنهم القراءة
CREATE POLICY product_reviews_select_all
  ON public.product_reviews
  FOR SELECT
  TO authenticated
  USING (true);

-- INSERT: المستخدم المصادق يمكنه إضافة تقييم
-- سيتم التحقق من القيود في الـ Function
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

-- ============================================================================
-- 3. review_helpful_votes POLICIES
-- ============================================================================

-- SELECT: الجميع يمكنهم القراءة
CREATE POLICY review_helpful_votes_select_all
  ON public.review_helpful_votes
  FOR SELECT
  TO authenticated
  USING (true);

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



-- ============================================================================
-- نهاية RLS Policies
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ RLS Policies created successfully for Review System!';
  RAISE NOTICE '🔒 All tables secured with Row Level Security';
END $$;
