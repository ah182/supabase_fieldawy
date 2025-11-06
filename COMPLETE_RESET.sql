-- =====================================================
-- إعادة تعيين كاملة - COMPLETE RESET
-- =====================================================

-- الخطوة 1: حذف كل شيء
DROP TABLE IF EXISTS product_views CASCADE;
DROP FUNCTION IF EXISTS track_product_view CASCADE;
DROP FUNCTION IF EXISTS track_regular_product_view CASCADE;
DROP FUNCTION IF EXISTS track_ocr_product_view CASCADE;
DROP FUNCTION IF EXISTS track_surgical_tool_view CASCADE;
DROP FUNCTION IF EXISTS track_offer_view CASCADE;
DROP FUNCTION IF EXISTS track_course_view CASCADE;
DROP FUNCTION IF EXISTS track_book_view CASCADE;

-- الخطوة 2: إنشاء الجدول
CREATE TABLE product_views (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id TEXT NOT NULL,              
  user_id UUID,
  user_role TEXT,
  product_type TEXT,
  viewed_at TIMESTAMPTZ DEFAULT NOW()
);

-- الخطوة 3: إنشاء Indexes
CREATE INDEX idx_pv_product ON product_views(product_id);
CREATE INDEX idx_pv_user ON product_views(user_id);
CREATE INDEX idx_pv_date ON product_views(viewed_at DESC);
CREATE INDEX idx_pv_type ON product_views(product_type);

-- الخطوة 4: تعطيل RLS مؤقتاً
ALTER TABLE product_views DISABLE ROW LEVEL SECURITY;

-- الخطوة 5: Function بسيطة جداً
CREATE OR REPLACE FUNCTION track_product_view(
  p_product_id TEXT,
  p_product_type TEXT DEFAULT 'regular'
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO product_views (product_id, product_type, user_role)
  VALUES (p_product_id, p_product_type, COALESCE((SELECT role FROM users WHERE uid = auth.uid()), 'viewer'));
  
  RETURN 'SUCCESS: Inserted ' || p_product_id;
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END;
$$;

-- الخطوة 6: منح الصلاحيات
GRANT ALL ON TABLE product_views TO authenticated;
GRANT ALL ON TABLE product_views TO anon;
GRANT ALL ON TABLE product_views TO public;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO public;

-- الخطوة 7: اختبار INSERT مباشر
INSERT INTO product_views (product_id, product_type, user_role)
VALUES ('reset-direct-test', 'regular', 'test');

-- الخطوة 8: اختبار Function
SELECT track_product_view('reset-function-test', 'regular');

-- الخطوة 9: التحقق من البيانات
SELECT 
  id,
  product_id,
  product_type,
  user_role,
  viewed_at
FROM product_views
ORDER BY viewed_at DESC;

-- الخطوة 10: عدد الصفوف
SELECT COUNT(*) as total_rows FROM product_views;

-- =====================================================
-- إذا نجح كل شيء، يمكنك تفعيل RLS لاحقاً:
-- =====================================================
-- ALTER TABLE product_views ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY pv_insert ON product_views FOR INSERT WITH CHECK (true);
-- CREATE POLICY pv_select ON product_views FOR SELECT USING (true);

