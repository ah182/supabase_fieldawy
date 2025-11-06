-- =====================================================
-- تحديث Function مع Logging محسّن
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
  RAISE NOTICE 'track_product_view called with: product_id=%, type=%', p_product_id, p_product_type;
  
  v_user_id := auth.uid();
  RAISE NOTICE 'User ID: %', COALESCE(v_user_id::TEXT, 'NULL');
  
  IF v_user_id IS NOT NULL THEN
    SELECT role INTO v_user_role FROM users WHERE uid = v_user_id;
    RAISE NOTICE 'User role: %', COALESCE(v_user_role, 'NULL');
  END IF;
  
  RAISE NOTICE 'Inserting into product_views...';
  INSERT INTO product_views (product_id, user_id, user_role, product_type)
  VALUES (p_product_id, v_user_id, COALESCE(v_user_role, 'viewer'), p_product_type);
  RAISE NOTICE 'Insert successful!';
  
  -- Update views counter
  IF p_product_type = 'regular' THEN
    BEGIN
      RAISE NOTICE 'Updating distributor_products...';
      UPDATE distributor_products SET views = COALESCE(views, 0) + 1
      WHERE product_id = p_product_id OR id::TEXT = p_product_id;
      RAISE NOTICE 'Update successful!';
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Update failed: %', SQLERRM;
    END;
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
  
  RAISE NOTICE 'track_product_view completed successfully!';
  
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'ERROR in track_product_view: %', SQLERRM;
  -- لا ترفع الخطأ، فقط سجله
END;
$$;

GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO anon;

