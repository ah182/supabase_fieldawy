-- =====================================================
-- FINAL Product Views Tracking System
-- نظام تتبع المشاهدات النهائي
-- =====================================================

-- =====================================================
-- STEP 1: Create product_views table
-- =====================================================
CREATE TABLE IF NOT EXISTS public.product_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id TEXT NOT NULL,
  user_id UUID,
  user_role TEXT,
  product_type TEXT,
  viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- STEP 2: Create indexes
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_product_views_product ON public.product_views(product_id);
CREATE INDEX IF NOT EXISTS idx_product_views_user ON public.product_views(user_id);
CREATE INDEX IF NOT EXISTS idx_product_views_date ON public.product_views(viewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_views_type ON public.product_views(product_type);

-- =====================================================
-- STEP 3: Enable RLS
-- =====================================================
ALTER TABLE public.product_views ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS product_views_insert_all ON public.product_views;
CREATE POLICY product_views_insert_all
ON public.product_views
FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS product_views_select_all ON public.product_views;
CREATE POLICY product_views_select_all
ON public.product_views
FOR SELECT
USING (true);

-- =====================================================
-- STEP 4: Main tracking function
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
  v_user_id := auth.uid();

  IF v_user_id IS NOT NULL THEN
    SELECT role INTO v_user_role
    FROM public.users
    WHERE uid = v_user_id;
  END IF;

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

  IF p_product_type = 'regular' THEN
    BEGIN
      UPDATE distributor_products
      SET views = COALESCE(views, 0) + 1
      WHERE product_id = p_product_id OR id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  ELSIF p_product_type = 'ocr' THEN
    BEGIN
      UPDATE distributor_ocr_products
      SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id OR ocr_product_id = p_product_id;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  ELSIF p_product_type = 'surgical' THEN
    BEGIN
      UPDATE distributor_surgical_tools
      SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  ELSIF p_product_type = 'offer' THEN
    BEGIN
      UPDATE offers
      SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  ELSIF p_product_type = 'course' THEN
    BEGIN
      UPDATE courses
      SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  ELSIF p_product_type = 'book' THEN
    BEGIN
      UPDATE books
      SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO anon;

-- =====================================================
-- STEP 5: Helper functions
-- =====================================================
CREATE OR REPLACE FUNCTION track_regular_product_view(p_product_id TEXT)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  SELECT track_product_view(p_product_id, 'regular');
$$;
GRANT EXECUTE ON FUNCTION track_regular_product_view(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_regular_product_view(TEXT) TO anon;




CREATE OR REPLACE FUNCTION track_ocr_product_view(p_product_id TEXT)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  SELECT track_product_view(p_product_id, 'ocr');
$$;
GRANT EXECUTE ON FUNCTION track_ocr_product_view(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_ocr_product_view(TEXT) TO anon;

CREATE OR REPLACE FUNCTION track_surgical_tool_view(p_product_id TEXT)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  SELECT track_product_view(p_product_id, 'surgical');
$$;
GRANT EXECUTE ON FUNCTION track_surgical_tool_view(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_surgical_tool_view(TEXT) TO anon;

CREATE OR REPLACE FUNCTION track_offer_view(p_product_id TEXT)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  SELECT track_product_view(p_product_id, 'offer');
$$;
GRANT EXECUTE ON FUNCTION track_offer_view(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_offer_view(TEXT) TO anon;

CREATE OR REPLACE FUNCTION track_course_view(p_product_id TEXT)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  SELECT track_product_view(p_product_id, 'course');
$$;
GRANT EXECUTE ON FUNCTION track_course_view(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_course_view(TEXT) TO anon;

CREATE OR REPLACE FUNCTION track_book_view(p_product_id TEXT)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  SELECT track_product_view(p_product_id, 'book');
$$;
GRANT EXECUTE ON FUNCTION track_book_view(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_book_view(TEXT) TO anon;
