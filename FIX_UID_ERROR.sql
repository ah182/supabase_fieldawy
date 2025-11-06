-- =====================================================
-- إصلاح خطأ column "uid" does not exist
-- =====================================================

-- أولاً: دعنا نتحقق من اسم العمود الصحيح في جدول users
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name IN ('id', 'uid', 'user_id')
ORDER BY column_name;

-- =====================================================
-- Function محدثة بدون الاعتماد على جدول users
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
  
  -- محاولة الحصول على role (مع معالجة الخطأ)
  IF v_user_id IS NOT NULL THEN
    BEGIN
      -- محاولة مع uid
      SELECT role INTO v_user_role FROM users WHERE uid = v_user_id;
    EXCEPTION WHEN OTHERS THEN
      BEGIN
        -- محاولة مع id
        SELECT role INTO v_user_role FROM users WHERE id = v_user_id;
      EXCEPTION WHEN OTHERS THEN
        -- إذا فشل كل شيء، استخدم viewer
        v_user_role := 'viewer';
      END;
    END;
  ELSE
    v_user_role := 'viewer';
  END IF;
  
  -- INSERT في product_views
  INSERT INTO product_views (product_id, user_id, user_role, product_type)
  VALUES (p_product_id, v_user_id, v_user_role, p_product_type);
  
  RETURN 'SUCCESS: Inserted ' || p_product_id;
  
EXCEPTION WHEN OTHERS THEN
  RETURN 'ERROR: ' || SQLERRM;
END;
$$;

GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT) TO public;

-- اختبار
SELECT track_product_view('fix-uid-test', 'regular');

-- التحقق
SELECT * FROM product_views WHERE product_id = 'fix-uid-test';

