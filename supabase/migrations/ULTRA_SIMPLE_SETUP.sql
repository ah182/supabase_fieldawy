-- =====================================================
-- Ultra Simple Product Views Setup
-- نظام بسيط جداً بدون أي تعقيدات
-- =====================================================

-- الخطوة 1: حذف الجدول القديم إذا كان موجوداً
DROP TABLE IF EXISTS public.product_views CASCADE;

-- الخطوة 2: إنشاء الجدول من جديد
CREATE TABLE public.product_views (
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

-- الخطوة 4: تفعيل RLS
ALTER TABLE product_views ENABLE ROW LEVEL SECURITY;

-- الخطوة 5: Policies
CREATE POLICY pv_insert ON product_views FOR INSERT WITH CHECK (true);
CREATE POLICY pv_select ON product_views FOR SELECT USING (true);

-- الخطوة 6: Function بسيطة جداً
CREATE OR REPLACE FUNCTION track_view(
  p_id TEXT,
  p_type TEXT DEFAULT 'regular'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO product_views (product_id, user_id, user_role, product_type)
  VALUES (
    p_id,
    auth.uid(),
    (SELECT role FROM users WHERE uid = auth.uid()),
    p_type
  );
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
$$;

-- الخطوة 7: منح الصلاحيات
GRANT EXECUTE ON FUNCTION track_view(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_view(TEXT, TEXT) TO anon;

-- الخطوة 8: اختبار
SELECT track_view('test-123', 'regular');
SELECT * FROM product_views;

