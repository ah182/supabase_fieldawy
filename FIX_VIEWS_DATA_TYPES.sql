-- =====================================================
-- FIX VIEWS DATA TYPES (FINAL)
-- حل مشكلة أنواع البيانات (TEXT vs UUID)
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
  -- 1. Log Analytics (Optional)
  INSERT INTO public.product_views (
    product_id, product_type, viewed_at
  ) VALUES (
    p_product_id, p_product_type, NOW()
  );

  -- 2. UPDATE Regular Products (ID is TEXT)
  -- This table uses TEXT for 'id' and 'product_id', so we use p_product_id directly.
  UPDATE distributor_products
  SET views = COALESCE(views, 0) + 1
  WHERE id = p_product_id OR product_id = p_product_id;

  -- 3. UPDATE OCR Products (ID is UUID)
  -- This table uses UUID, so we MUST cast safely.
  BEGIN
    v_uuid := p_product_id::UUID;
    
    IF v_uuid IS NOT NULL THEN
      UPDATE distributor_ocr_products
      SET views = COALESCE(views, 0) + 1
      WHERE id = v_uuid OR ocr_product_id = v_uuid;
      
      -- Also try Surgical Tools (UUID)
      UPDATE distributor_surgical_tools
      SET views = COALESCE(views, 0) + 1
      WHERE id = v_uuid;
      
      -- Also try Offers (UUID)
      UPDATE offers
      SET views = COALESCE(views, 0) + 1
      WHERE id = v_uuid;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- If p_product_id is not a valid UUID, just ignore OCR update (it can't be an OCR product)
    NULL;
  END;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO public;
