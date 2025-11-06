-- =====================================================
-- Function بسيطة بدون الاعتماد على جدول users
-- =====================================================

CREATE OR REPLACE FUNCTION track_product_view(
  p_product_id TEXT,
  p_product_type TEXT DEFAULT 'regular'
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- INSERT مباشر بدون البحث في جدول users
  INSERT INTO product_views (
    product_id, 
    user_id, 
    user_role, 
    product_type
  )
  VALUES (
    p_product_id,
    auth.uid(),
    'viewer',
    p_product_type
  );
  
  RETURN 'SUCCESS';
  
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END;
$$;

GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO public;

-- اختبار
SELECT track_product_view('simple-no-users-test', 'regular');

-- التحقق
SELECT * FROM product_views WHERE product_id = 'simple-no-users-test';

-- عرض جميع البيانات
SELECT 
  product_id,
  user_id,
  user_role,
  product_type,
  viewed_at
FROM product_views
ORDER BY viewed_at DESC
LIMIT 10;

