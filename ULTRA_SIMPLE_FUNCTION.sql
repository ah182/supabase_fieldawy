-- =====================================================
-- Function بسيطة جداً للاختبار
-- =====================================================

-- حذف Function القديمة
DROP FUNCTION IF EXISTS track_product_view(TEXT, TEXT) CASCADE;

-- Function جديدة بسيطة جداً
CREATE OR REPLACE FUNCTION track_product_view(
  p_product_id TEXT,
  p_product_type TEXT DEFAULT 'regular'
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- فقط INSERT بدون أي شيء آخر
  INSERT INTO product_views (product_id, product_type, user_role)
  VALUES (p_product_id, p_product_type, 'test');
  
  RETURN 'SUCCESS';
END;
$$;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO public;

-- اختبار
SELECT track_product_view('simple-test-001', 'regular');

-- التحقق
SELECT * FROM product_views WHERE product_id = 'simple-test-001';

