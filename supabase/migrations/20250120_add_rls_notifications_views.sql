-- ============================================
-- إضافة RLS للـ Views وجداول الإشعارات
-- ============================================

-- ============================================
-- 1️⃣ RLS لجدول user_tokens (FCM Tokens)
-- ============================================

-- تفعيل RLS
ALTER TABLE user_tokens ENABLE ROW LEVEL SECURITY;

-- Policy: المستخدم يمكنه قراءة tokens الخاصة به فقط
CREATE POLICY "Users can view their own tokens"
ON user_tokens
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: المستخدم يمكنه إضافة tokens لنفسه فقط
CREATE POLICY "Users can insert their own tokens"
ON user_tokens
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: المستخدم يمكنه تحديث tokens الخاصة به فقط
CREATE POLICY "Users can update their own tokens"
ON user_tokens
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: المستخدم يمكنه حذف tokens الخاصة به فقط
CREATE POLICY "Users can delete their own tokens"
ON user_tokens
FOR DELETE
USING (auth.uid() = user_id);

-- Policy: Admin يمكنه رؤية جميع tokens (للإدارة والدعم)
CREATE POLICY "Admins can view all tokens"
ON user_tokens
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);

-- ============================================
-- 2️⃣ RLS لجدول notification_logs
-- ============================================

-- تفعيل RLS
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

-- Policy: جميع المستخدمين المصادقين يمكنهم قراءة سجل الإشعارات
-- (للشفافية - يمكن للجميع رؤية الإشعارات المُرسلة)
CREATE POLICY "Authenticated users can view notification logs"
ON notification_logs
FOR SELECT
USING (auth.role() = 'authenticated');

-- Policy: فقط النظام (service_role) يمكنه إضافة سجلات
CREATE POLICY "System can insert notification logs"
ON notification_logs
FOR INSERT
WITH CHECK (auth.role() = 'service_role');

-- Policy: Admin يمكنه تحديث حالة الإشعارات
CREATE POLICY "Admins can update notification logs"
ON notification_logs
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);

-- Policy: Admin يمكنه حذف سجلات قديمة
CREATE POLICY "Admins can delete notification logs"
ON notification_logs
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);

-- ============================================
-- 3️⃣ RLS للـ Views
-- ============================================

-- ملاحظة: Views ترث RLS من الجداول الأساسية
-- لكن يمكننا إضافة policies إضافية

-- View: distributor_products_expiring_soon
-- ترث RLS من distributor_products و products

-- View: distributor_products_price_changes
-- ترث RLS من distributor_products و products

-- View: notification_stats
-- ترث RLS من notification_logs

-- ============================================
-- 4️⃣ Policies إضافية للجداول الأساسية (إذا لزم)
-- ============================================

-- تحديث RLS لـ distributor_products لدعم Views
-- (إذا لم تكن موجودة بالفعل)

DO $$ 
BEGIN
  -- التحقق من وجود policy
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'distributor_products' 
    AND policyname = 'distributor_products_select_all_authenticated'
  ) THEN
    CREATE POLICY "distributor_products_select_all_authenticated"
    ON distributor_products
    FOR SELECT
    USING (auth.role() = 'authenticated');
  END IF;
END $$;

-- ============================================
-- 5️⃣ Functions Security
-- ============================================

-- التأكد من أن Functions آمنة

-- get_expiring_products: SECURITY DEFINER (تعمل بصلاحيات المالك)
ALTER FUNCTION get_expiring_products(int) SECURITY DEFINER;

-- get_price_changed_products: SECURITY DEFINER
ALTER FUNCTION get_price_changed_products(int) SECURITY DEFINER;

-- upsert_user_token: SECURITY DEFINER (موجود بالفعل)
-- هذا يسمح للمستخدم بحفظ token بدون التحقق من RLS

-- delete_user_token: SECURITY DEFINER
ALTER FUNCTION delete_user_token(uuid, text) SECURITY DEFINER;

-- get_users_by_token: SECURITY DEFINER (للمستخدمين المصادقين فقط)
ALTER FUNCTION get_users_by_token(text) SECURITY DEFINER;

-- get_user_devices_count: SECURITY DEFINER
ALTER FUNCTION get_user_devices_count(uuid) SECURITY DEFINER;

-- log_notification: SECURITY DEFINER
ALTER FUNCTION log_notification(text, text, text, text, uuid, text, text) SECURITY DEFINER;

-- ============================================
-- 6️⃣ Grant Permissions
-- ============================================

-- السماح للمستخدمين المصادقين باستخدام Functions
GRANT EXECUTE ON FUNCTION get_expiring_products(int) TO authenticated;
GRANT EXECUTE ON FUNCTION get_price_changed_products(int) TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_user_token(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_token(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_users_by_token(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_devices_count(uuid) TO authenticated;

-- log_notification فقط للنظام
GRANT EXECUTE ON FUNCTION log_notification(text, text, text, text, uuid, text, text) TO service_role;

-- ============================================
-- 7️⃣ View Permissions
-- ============================================

-- السماح للمستخدمين المصادقين بقراءة Views
-- ملاحظة: distributor_products_expiring_soon و distributor_products_price_changes تم حذفهما
-- استخدم Functions بدلاً منهما
GRANT SELECT ON notification_stats TO authenticated;

-- ============================================
-- 8️⃣ تعليقات توضيحية
-- ============================================

COMMENT ON POLICY "Users can view their own tokens" ON user_tokens IS 
'المستخدم يمكنه رؤية FCM tokens الخاصة به فقط';

COMMENT ON POLICY "Admins can view all tokens" ON user_tokens IS 
'المسؤولون يمكنهم رؤية جميع tokens للإدارة';

COMMENT ON POLICY "Authenticated users can view notification logs" ON notification_logs IS 
'جميع المستخدمين المصادقين يمكنهم رؤية سجل الإشعارات للشفافية';

COMMENT ON POLICY "System can insert notification logs" ON notification_logs IS 
'فقط النظام يمكنه إضافة سجلات إشعارات جديدة';

-- ============================================
-- 9️⃣ اختبار RLS
-- ============================================

-- للاختبار: تسجيل الدخول كمستخدم عادي
-- يجب أن يرى tokens الخاصة به فقط
-- SELECT * FROM user_tokens;

-- للاختبار: الوصول للـ Views
-- SELECT * FROM distributor_products_expiring_soon;
-- SELECT * FROM distributor_products_price_changes;

-- للاختبار: استخدام Functions
-- SELECT * FROM get_expiring_products(60);
-- SELECT * FROM get_price_changed_products(30);
