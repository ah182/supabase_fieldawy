-- اختبار اتصال Supabase وجدول user_tokens

-- 1. التحقق من وجود الجدول
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_name = 'user_tokens'
) as table_exists;

-- 2. عرض جميع الـ Tokens المحفوظة
SELECT 
  ut.id,
  ut.user_id,
  ut.token,
  ut.device_type,
  ut.device_name,
  ut.created_at,
  ut.updated_at
FROM user_tokens ut
ORDER BY ut.created_at DESC;

-- 3. عدد Tokens لكل مستخدم
SELECT 
  u.email,
  COUNT(ut.id) as token_count
FROM auth.users u
LEFT JOIN user_tokens ut ON u.id = ut.user_id
GROUP BY u.id, u.email
ORDER BY token_count DESC;

-- 4. التحقق من وجود Functions
SELECT 
  proname as function_name,
  pg_get_function_arguments(oid) as arguments
FROM pg_proc
WHERE proname IN (
  'upsert_user_token',
  'get_all_active_tokens',
  'get_user_tokens',
  'cleanup_old_tokens'
)
ORDER BY proname;

-- 5. التحقق من RLS Policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'user_tokens';

-- 6. اختبار إضافة token يدوياً (استبدل القيم)
-- INSERT INTO user_tokens (user_id, token, device_type)
-- VALUES (
--   'your-user-uuid-here',
--   'test-fcm-token-12345',
--   'Android'
-- );

-- 7. اختبار الدالة upsert_user_token (استبدل القيم)
-- SELECT upsert_user_token(
--   'your-user-uuid-here'::uuid,
--   'test-fcm-token-67890',
--   'Android',
--   'Test Device'
-- );
