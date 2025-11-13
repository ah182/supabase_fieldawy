-- تنظيف الـ Tokens القديمة والمكررة
-- يحسن نسبة نجاح الإشعارات من 1/59 إلى معدل أعلى

-- =====================================================
-- 1. حذف Tokens القديمة (أكثر من 90 يوم)
-- =====================================================

-- الـ tokens القديمة غالباً expired أو المستخدم حذف التطبيق
DELETE FROM user_tokens 
WHERE updated_at < NOW() - INTERVAL '90 days';

-- =====================================================
-- 2. حذف Tokens المكررة (Keep Latest Only)
-- =====================================================

-- إذا المستخدم عنده أكثر من token، نحتفظ بالأحدث فقط
DELETE FROM user_tokens
WHERE id IN (
  SELECT id 
  FROM (
    SELECT 
      id,
      ROW_NUMBER() OVER (
        PARTITION BY user_id 
        ORDER BY updated_at DESC
      ) as rn
    FROM user_tokens
  ) t
  WHERE rn > 1
);

-- =====================================================
-- 3. إنشاء Function لتنظيف تلقائي
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_expired_tokens()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  -- حذف tokens أكثر من 90 يوم
  DELETE FROM user_tokens 
  WHERE updated_at < NOW() - INTERVAL '90 days';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  -- حذف tokens مكررة (keep latest per user)
  DELETE FROM user_tokens
  WHERE id IN (
    SELECT id 
    FROM (
      SELECT 
        id,
        ROW_NUMBER() OVER (
          PARTITION BY user_id 
          ORDER BY updated_at DESC
        ) as rn
      FROM user_tokens
    ) t
    WHERE rn > 1
  );
  
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. جدولة تنظيف أسبوعي (Optional - Supabase Cron)
-- =====================================================

-- يمكن إضافة Cron job في Supabase لتشغيل هذا أسبوعياً
-- أو تشغيله يدوياً كل فترة:
-- SELECT cleanup_expired_tokens();

-- =====================================================
-- 5. إحصائيات بعد التنظيف
-- =====================================================

SELECT 
  'Cleanup Complete!' as status,
  COUNT(*) as remaining_tokens,
  COUNT(DISTINCT user_id) as unique_users,
  ROUND(AVG(EXTRACT(EPOCH FROM (NOW() - updated_at)) / 86400), 1) as avg_age_days
FROM user_tokens;

-- =====================================================
-- 6. View للـ Tokens النشطة (آخر 30 يوم)
-- =====================================================

CREATE OR REPLACE VIEW active_user_tokens AS
SELECT 
  user_id,
  token,
  device_type,
  device_name,
  updated_at,
  EXTRACT(EPOCH FROM (NOW() - updated_at)) / 86400 as age_days
FROM user_tokens
WHERE updated_at > NOW() - INTERVAL '30 days'
ORDER BY updated_at DESC;

-- =====================================================
-- SUCCESS!
-- =====================================================

-- الآن الإشعارات ستعمل بشكل أفضل لأن:
-- ✅ Tokens القديمة تم حذفها
-- ✅ Tokens المكررة تم حذفها (token واحد لكل مستخدم)
-- ✅ Dashboard سيرسل لأحدث token لكل مستخدم

-- لتشغيل التنظيف مستقبلاً:
-- SELECT cleanup_expired_tokens();
