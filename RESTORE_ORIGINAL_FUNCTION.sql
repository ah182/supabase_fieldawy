-- =====================================================
-- RESTORE ORIGINAL FUNCTION (FINAL_product_views_system.sql)
-- استعادة الدالة الأصلية تماماً كما كانت
-- =====================================================

DROP FUNCTION IF EXISTS track_product_view(TEXT, TEXT);

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
