-- =====================================================
-- Function الصحيحة مع استخدام users.id
-- =====================================================

CREATE OR REPLACE FUNCTION track_product_view(
  p_product_id TEXT,
  p_product_type TEXT DEFAULT 'regular'
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
BEGIN
  -- الحصول على user_id من auth
  v_user_id := auth.uid();
  
  -- الحصول على role من جدول users (باستخدام id وليس uid)
  IF v_user_id IS NOT NULL THEN
    SELECT role INTO v_user_role 
    FROM users 
    WHERE id = v_user_id;
  END IF;
  
  -- INSERT في product_views
  INSERT INTO product_views (
    product_id, 
    user_id, 
    user_role, 
    product_type
  )
  VALUES (
    p_product_id,
    v_user_id,
    COALESCE(v_user_role, 'viewer'),
    p_product_type
  );
  
  -- تحديث عداد المشاهدات في الجدول المناسب
  IF p_product_type = 'regular' THEN
    BEGIN
      UPDATE distributor_products 
      SET views = COALESCE(views, 0) + 1
      WHERE product_id = p_product_id OR id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  ELSIF p_product_type = 'ocr' THEN
    BEGIN
      UPDATE distributor_ocr_products 
      SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id OR ocr_product_id = p_product_id;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  ELSIF p_product_type = 'surgical' THEN
    BEGIN
      UPDATE distributor_surgical_tools 
      SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  ELSIF p_product_type = 'offer' THEN
    BEGIN
      UPDATE offers 
      SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  ELSIF p_product_type = 'course' THEN
    BEGIN
      UPDATE courses 
      SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  ELSIF p_product_type = 'book' THEN
    BEGIN
      UPDATE books 
      SET views = COALESCE(views, 0) + 1
      WHERE id::TEXT = p_product_id;
    EXCEPTION WHEN OTHERS THEN NULL; END;
  END IF;
  
  RETURN 'SUCCESS';
  
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END;
$$;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO public;

-- Helper Functions
CREATE OR REPLACE FUNCTION track_regular_product_view(p_product_id TEXT)
RETURNS TEXT LANGUAGE sql SECURITY DEFINER AS $$
  SELECT track_product_view(p_product_id, 'regular');
$$;

CREATE OR REPLACE FUNCTION track_ocr_product_view(p_product_id TEXT)
RETURNS TEXT LANGUAGE sql SECURITY DEFINER AS $$
  SELECT track_product_view(p_product_id, 'ocr');
$$;

CREATE OR REPLACE FUNCTION track_surgical_tool_view(p_product_id TEXT)
RETURNS TEXT LANGUAGE sql SECURITY DEFINER AS $$
  SELECT track_product_view(p_product_id, 'surgical');
$$;

CREATE OR REPLACE FUNCTION track_offer_view(p_product_id TEXT)
RETURNS TEXT LANGUAGE sql SECURITY DEFINER AS $$
  SELECT track_product_view(p_product_id, 'offer');
$$;

CREATE OR REPLACE FUNCTION track_course_view(p_product_id TEXT)
RETURNS TEXT LANGUAGE sql SECURITY DEFINER AS $$
  SELECT track_product_view(p_product_id, 'course');
$$;

CREATE OR REPLACE FUNCTION track_book_view(p_product_id TEXT)
RETURNS TEXT LANGUAGE sql SECURITY DEFINER AS $$
  SELECT track_product_view(p_product_id, 'book');
$$;

GRANT EXECUTE ON FUNCTION track_regular_product_view(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION track_ocr_product_view(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION track_surgical_tool_view(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION track_offer_view(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION track_course_view(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION track_book_view(TEXT) TO authenticated, anon, public;

-- اختبار
SELECT track_product_view('final-test-001', 'regular');

-- التحقق
SELECT 
  product_id,
  user_id,
  user_role,
  product_type,
  viewed_at
FROM product_views 
WHERE product_id = 'final-test-001';

-- عرض جميع البيانات
SELECT 
  product_id,
  user_role,
  product_type,
  viewed_at
FROM product_views
ORDER BY viewed_at DESC
LIMIT 10;

