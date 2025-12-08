-- =====================================================
-- FIX PRODUCT VIEWS V2 (UUID & DIRECT UPDATE)
-- حل نهائي مباشر: التعامل مع UUID وتحديث الجدولين
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
  v_uuid UUID;
BEGIN
  -- 1. Try to cast ID to UUID
  BEGIN
    v_uuid := p_product_id::UUID;
  EXCEPTION WHEN OTHERS THEN
    v_uuid := NULL;
  END;

  -- 2. Log Analytics (Optional, can be removed if causing issues)
  INSERT INTO public.product_views (
    product_id, product_type, viewed_at
  ) VALUES (
    p_product_id, p_product_type, NOW()
  );

  -- 3. UPDATE LOGIC (Try All Relevant Tables using UUID if valid)
  
  IF v_uuid IS NOT NULL THEN
    -- Try updating Regular Products
    UPDATE distributor_products
    SET views = COALESCE(views, 0) + 1
    WHERE id = v_uuid OR product_id = p_product_id; -- Try both ID and ProductID column

    -- Try updating OCR Products (The critical part)
    UPDATE distributor_ocr_products
    SET views = COALESCE(views, 0) + 1
    WHERE id = v_uuid OR ocr_product_id = v_uuid; -- Match either Row ID or Original Product ID
    
    -- Try updating Surgical Tools
    UPDATE distributor_surgical_tools
    SET views = COALESCE(views, 0) + 1
    WHERE id = v_uuid;
    
    -- Try updating Offers
    UPDATE offers
    SET views = COALESCE(views, 0) + 1
    WHERE id = v_uuid;

  ELSE
    -- Fallback for non-UUID IDs (if any exist)
    UPDATE distributor_products
    SET views = COALESCE(views, 0) + 1
    WHERE product_id = p_product_id;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO public;
