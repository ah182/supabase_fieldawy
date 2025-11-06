-- =====================================================
-- Clean Install - Product Views Tracking System
-- تثبيت نظيف - حذف القديم وإنشاء جديد
-- =====================================================

-- =====================================================
-- STEP 1: حذف كل شيء قديم
-- =====================================================

-- حذف Functions القديمة
DROP FUNCTION IF EXISTS track_product_view(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS track_regular_product_view(TEXT) CASCADE;
DROP FUNCTION IF EXISTS track_ocr_product_view(TEXT) CASCADE;
DROP FUNCTION IF EXISTS track_surgical_tool_view(TEXT) CASCADE;
DROP FUNCTION IF EXISTS track_offer_view(TEXT) CASCADE;
DROP FUNCTION IF EXISTS track_course_view(TEXT) CASCADE;
DROP FUNCTION IF EXISTS track_book_view(TEXT) CASCADE;

-- حذف الجدول القديم
DROP TABLE IF EXISTS public.product_views CASCADE;

-- =====================================================
-- STEP 2: إنشاء جدول product_views جديد
-- =====================================================
CREATE TABLE public.product_views (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id TEXT NOT NULL,
  user_id UUID,
  user_role TEXT,
  product_type TEXT,
  viewed_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- STEP 3: إنشاء Indexes
-- =====================================================
CREATE INDEX idx_product_views_product ON product_views(product_id);
CREATE INDEX idx_product_views_user ON product_views(user_id);
CREATE INDEX idx_product_views_date ON product_views(viewed_at DESC);
CREATE INDEX idx_product_views_type ON product_views(product_type);

-- =====================================================
-- STEP 4: تفعيل RLS
-- =====================================================
ALTER TABLE product_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY product_views_insert_all ON product_views
FOR INSERT WITH CHECK (true);

CREATE POLICY product_views_select_all ON product_views
FOR SELECT USING (true);

-- =====================================================
-- STEP 5: Function رئيسية
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
    SELECT role INTO v_user_role FROM users WHERE uid = v_user_id;
  END IF;
  
  INSERT INTO product_views (product_id, user_id, user_role, product_type)
  VALUES (p_product_id, v_user_id, COALESCE(v_user_role, 'viewer'), p_product_type);
  
  IF p_product_type = 'regular' THEN
    BEGIN
      UPDATE distributor_products SET views = COALESCE(views, 0) + 1
      WHERE product_id = p_product_id OR id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  ELSIF p_product_type = 'ocr' THEN
    BEGIN
      UPDATE distributor_ocr_products SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id OR ocr_product_id = p_product_id;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  ELSIF p_product_type = 'surgical' THEN
    BEGIN
      UPDATE distributor_surgical_tools SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  ELSIF p_product_type = 'offer' THEN
    BEGIN
      UPDATE offers SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  ELSIF p_product_type = 'course' THEN
    BEGIN
      UPDATE courses SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  ELSIF p_product_type = 'book' THEN
    BEGIN
      UPDATE books SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO anon;

-- =====================================================
-- STEP 6: Helper Functions
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

