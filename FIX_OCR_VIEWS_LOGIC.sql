-- =====================================================
-- FIX OCR VIEWS LOGIC (UUID CASTING FIX)
-- إصلاح الدالة مع تحويل الأنواع الصحيح للـ UUID
-- =====================================================

DROP FUNCTION IF EXISTS track_product_view(TEXT, TEXT);

CREATE OR REPLACE FUNCTION track_product_view(
  p_product_id TEXT,
  p_product_type TEXT DEFAULT 'regular'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_rows_updated INT DEFAULT 0;
  v_uuid UUID; -- To hold the casted UUID
BEGIN
  -- Analytics Log
  v_user_id := auth.uid();
  IF v_user_id IS NOT NULL THEN
    SELECT role INTO v_user_role FROM public.users WHERE uid = v_user_id;
  END IF;

  INSERT INTO public.product_views (
    product_id, user_id, user_role, product_type, viewed_at
  ) VALUES (
    p_product_id, v_user_id, COALESCE(v_user_role, 'viewer'), p_product_type, NOW()
  );

  -- Attempt to cast p_product_id to UUID safely
  BEGIN
    v_uuid := p_product_id::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_uuid := NULL; -- If not a valid UUID, treat as NULL
  END;

  -- ===================================================
  -- UPDATE LOGIC
  -- ===================================================

  -- 1. Try Regular Distributor Products (Uses 'product_id' which is TEXT usually, or 'id' which is UUID)
  UPDATE distributor_products
  SET views = COALESCE(views, 0) + 1
  WHERE product_id = p_product_id 
     OR (v_uuid IS NOT NULL AND id = v_uuid); -- Compare UUID with UUID
  
  GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

  -- 2. If not found, Try Distributor OCR Products (Uses UUIDs)
  IF v_rows_updated = 0 AND v_uuid IS NOT NULL THEN
    UPDATE distributor_ocr_products
    SET views = COALESCE(views, 0) + 1
    WHERE id = v_uuid OR ocr_product_id = v_uuid; -- Strict UUID comparison
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
  END IF;

  -- 3. Fallback: Main OCR Table (If not linked yet)
  IF v_rows_updated = 0 AND v_uuid IS NOT NULL THEN
    UPDATE ocr_products
    SET views = COALESCE(views, 0) + 1
    WHERE id = v_uuid;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
  END IF;

  RETURN v_rows_updated > 0;

EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$;

GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO public;
