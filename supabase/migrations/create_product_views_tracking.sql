-- =====================================================
-- Product Views Tracking System
-- تسجيل المشاهدات في جدول product_views
-- =====================================================

-- =====================================================
-- 1. إنشاء/تحديث جدول product_views
-- =====================================================
CREATE TABLE IF NOT EXISTS public.product_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id TEXT NOT NULL,
  user_id UUID,
  user_role TEXT,
  product_type TEXT,
  viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes للأداء
CREATE INDEX IF NOT EXISTS idx_product_views_product ON public.product_views(product_id);
CREATE INDEX IF NOT EXISTS idx_product_views_user ON public.product_views(user_id);
CREATE INDEX IF NOT EXISTS idx_product_views_date ON public.product_views(viewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_views_type ON public.product_views(product_type);

-- =====================================================
-- 2. RLS Policies
-- =====================================================
ALTER TABLE public.product_views ENABLE ROW LEVEL SECURITY;

-- السماح للجميع بالإدراج (حتى غير المسجلين)
DROP POLICY IF EXISTS product_views_insert_all ON public.product_views;
CREATE POLICY product_views_insert_all
ON public.product_views
FOR INSERT
WITH CHECK (true);

-- السماح للجميع بالقراءة
DROP POLICY IF EXISTS product_views_select_all ON public.product_views;
CREATE POLICY product_views_select_all
ON public.product_views
FOR SELECT
USING (true);

-- =====================================================
-- 3. Function لتسجيل مشاهدة منتج
-- =====================================================
CREATE OR REPLACE FUNCTION track_product_view(
  p_product_id TEXT,
  p_product_type TEXT DEFAULT 'regular'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
BEGIN
  -- الحصول على معلومات المستخدم الحالي
  v_user_id := auth.uid();

  -- الحصول على دور المستخدم
  IF v_user_id IS NOT NULL THEN
    SELECT role INTO v_user_role
    FROM public.users
    WHERE uid = v_user_id;
  END IF;

  -- تسجيل المشاهدة
  INSERT INTO public.product_views (
    product_id,
    user_id,
    user_role,
    product_type,
    viewed_at
  ) VALUES (
    p_product_id,
    v_user_id,
    COALESCE(v_user_role, 'viewer'),
    p_product_type,
    NOW()
  );

  -- زيادة عداد المشاهدات في الجدول المناسب
  CASE p_product_type
    WHEN 'regular' THEN
      -- محاولة تحديث distributor_products
      BEGIN
        UPDATE distributor_products
        SET views = COALESCE(views, 0) + 1
        WHERE product_id = p_product_id OR id::TEXT = p_product_id;
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not update distributor_products: %', SQLERRM;
      END;

    WHEN 'ocr' THEN
      -- محاولة تحديث distributor_ocr_products
      BEGIN
        UPDATE distributor_ocr_products
        SET views = COALESCE(views, 0) + 1
        WHERE id::TEXT = p_product_id OR ocr_product_id = p_product_id;
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not update distributor_ocr_products: %', SQLERRM;
      END;

    WHEN 'surgical' THEN
      -- محاولة تحديث distributor_surgical_tools
      BEGIN
        UPDATE distributor_surgical_tools
        SET views = COALESCE(views, 0) + 1
        WHERE id::TEXT = p_product_id;
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not update distributor_surgical_tools: %', SQLERRM;
      END;

    WHEN 'offer' THEN
      -- محاولة تحديث offers
      BEGIN
        UPDATE offers
        SET views = COALESCE(views, 0) + 1
        WHERE id::TEXT = p_product_id;
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not update offers: %', SQLERRM;
      END;

    WHEN 'course' THEN
      -- محاولة تحديث courses (إذا كان الجدول موجوداً)
      BEGIN
        UPDATE courses
        SET views = COALESCE(views, 0) + 1
        WHERE id::TEXT = p_product_id;
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not update courses: %', SQLERRM;
      END;

    WHEN 'book' THEN
      -- محاولة تحديث books (إذا كان الجدول موجوداً)
      BEGIN
        UPDATE books
        SET views = COALESCE(views, 0) + 1
        WHERE id::TEXT = p_product_id;
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not update books: %', SQLERRM;
      END;
  END CASE;

EXCEPTION
  WHEN OTHERS THEN
    -- تسجيل الخطأ لكن لا ترفع استثناء
    RAISE NOTICE 'Error tracking view: %', SQLERRM;
END;
$$;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO anon;

-- =====================================================
-- 4. Function مبسطة للمنتجات العادية
-- =====================================================
CREATE OR REPLACE FUNCTION track_regular_product_view(p_product_id TEXT)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT track_product_view(p_product_id, 'regular');
$$;

GRANT EXECUTE ON FUNCTION track_regular_product_view(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_regular_product_view(TEXT) TO anon;

-- =====================================================
-- 5. Function للمنتجات OCR
-- =====================================================
CREATE OR REPLACE FUNCTION track_ocr_product_view(p_product_id TEXT)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT track_product_view(p_product_id, 'ocr');
$$;

GRANT EXECUTE ON FUNCTION track_ocr_product_view(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_ocr_product_view(TEXT) TO anon;

-- =====================================================
-- 6. Function للأدوات الجراحية
-- =====================================================
CREATE OR REPLACE FUNCTION track_surgical_tool_view(p_product_id TEXT)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT track_product_view(p_product_id, 'surgical');
$$;

GRANT EXECUTE ON FUNCTION track_surgical_tool_view(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_surgical_tool_view(TEXT) TO anon;

-- =====================================================
-- 7. Function للعروض
-- =====================================================
CREATE OR REPLACE FUNCTION track_offer_view(p_product_id TEXT)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT track_product_view(p_product_id, 'offer');
$$;

GRANT EXECUTE ON FUNCTION track_offer_view(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_offer_view(TEXT) TO anon;

-- =====================================================
-- 8. Function للكورسات
-- =====================================================
CREATE OR REPLACE FUNCTION track_course_view(p_product_id TEXT)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT track_product_view(p_product_id, 'course');
$$;

GRANT EXECUTE ON FUNCTION track_course_view(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_course_view(TEXT) TO anon;

-- =====================================================
-- 9. Function للكتب
-- =====================================================
CREATE OR REPLACE FUNCTION track_book_view(p_product_id TEXT)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT track_product_view(p_product_id, 'book');
$$;

GRANT EXECUTE ON FUNCTION track_book_view(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_book_view(TEXT) TO anon;

