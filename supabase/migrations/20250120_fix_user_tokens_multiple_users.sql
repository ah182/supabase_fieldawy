-- إصلاح جدول user_tokens للسماح بنفس token لأكثر من user

-- 1. حذف unique constraint القديم على token
ALTER TABLE user_tokens 
DROP CONSTRAINT IF EXISTS user_tokens_token_key;

-- 2. إضافة unique constraint مركب على (user_id, token)
-- هكذا نفس token يمكن أن يكون لمستخدمين مختلفين
-- لكن نفس المستخدم لا يمكنه تسجيل نفس token مرتين
ALTER TABLE user_tokens 
ADD CONSTRAINT user_tokens_user_id_token_key 
UNIQUE (user_id, token);

-- 3. إضافة index على token للبحث السريع
CREATE INDEX IF NOT EXISTS idx_user_tokens_token_lookup 
ON user_tokens(token);

-- 4. تحديث دالة upsert_user_token
CREATE OR REPLACE FUNCTION upsert_user_token(
  p_user_id uuid,
  p_token text,
  p_device_type text DEFAULT NULL,
  p_device_name text DEFAULT NULL
)
RETURNS void AS $$
BEGIN
  -- الآن upsert على أساس (user_id, token) معاً
  INSERT INTO user_tokens (user_id, token, device_type, device_name)
  VALUES (p_user_id, p_token, p_device_type, p_device_name)
  ON CONFLICT (user_id, token)
  DO UPDATE SET
    device_type = EXCLUDED.device_type,
    device_name = EXCLUDED.device_name,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. دالة للحصول على جميع المستخدمين لـ token معين
-- مفيدة لمعرفة كم حساب مسجل على نفس الجهاز
CREATE OR REPLACE FUNCTION get_users_by_token(p_token text)
RETURNS TABLE (
  user_id uuid,
  device_type text,
  device_name text,
  created_at timestamp with time zone
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ut.user_id,
    ut.device_type,
    ut.device_name,
    ut.created_at
  FROM user_tokens ut
  WHERE ut.token = p_token
  ORDER BY ut.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. دالة لعد عدد الأجهزة لكل مستخدم
CREATE OR REPLACE FUNCTION get_user_devices_count(p_user_id uuid)
RETURNS integer AS $$
DECLARE
  device_count integer;
BEGIN
  SELECT COUNT(DISTINCT token)
  INTO device_count
  FROM user_tokens
  WHERE user_id = p_user_id;
  
  RETURN device_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. دالة لحذف token لمستخدم محدد (بدلاً من حذف token من جميع المستخدمين)
CREATE OR REPLACE FUNCTION delete_user_token(
  p_user_id uuid,
  p_token text
)
RETURNS void AS $$
BEGIN
  DELETE FROM user_tokens
  WHERE user_id = p_user_id AND token = p_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- تعليقات توضيحية
COMMENT ON CONSTRAINT user_tokens_user_id_token_key ON user_tokens IS 
'يسمح بنفس token لمستخدمين مختلفين، لكن ليس لنفس المستخدم مرتين';

COMMENT ON FUNCTION get_users_by_token(text) IS 
'الحصول على جميع المستخدمين المسجلين على نفس الجهاز (token)';

COMMENT ON FUNCTION get_user_devices_count(uuid) IS 
'عد عدد الأجهزة المختلفة لمستخدم معين';

COMMENT ON FUNCTION delete_user_token(uuid, text) IS 
'حذف token لمستخدم محدد فقط، دون التأثير على مستخدمين آخرين على نفس الجهاز';
