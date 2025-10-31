-- ===================================================================
-- تطبيق إشعارات الكتب والكورسات - Script مجمع للتطبيق
-- ===================================================================
-- هذا الـ script يطبق جميع التحديثات المطلوبة لإضافة إشعارات الكتب والكورسات

-- ===================================================================
-- 1. إضافة أعمدة الكتب والكورسات لجدول notification_preferences
-- ===================================================================
ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS books BOOLEAN DEFAULT true;

ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS courses BOOLEAN DEFAULT true;

-- ===================================================================
-- 2. إنشاء دوال triggers للكتب والكورسات
-- ===================================================================

-- دالة للكتب
CREATE OR REPLACE FUNCTION notify_books_change()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url text;
  payload jsonb;
  should_send_notification boolean := true;
BEGIN
  -- فحص ما إذا كان التحديث فقط على عمود views
  IF TG_OP = 'UPDATE' THEN
    -- تحقق من أن التغيير ليس فقط على views أو updated_at
    IF NOT (
      OLD.name IS DISTINCT FROM NEW.name OR
      OLD.author IS DISTINCT FROM NEW.author OR
      OLD.description IS DISTINCT FROM NEW.description OR
      OLD.price IS DISTINCT FROM NEW.price OR
      OLD.phone IS DISTINCT FROM NEW.phone OR
      OLD.image_url IS DISTINCT FROM NEW.image_url
    ) THEN
      -- فقط views أو updated_at تم تحديثهما - لا نرسل إشعار
      RAISE NOTICE 'Skipping notification - only views or updated_at changed';
      RETURN NEW;
    END IF;
  END IF;

  -- الحصول على webhook URL
  webhook_url := current_setting('app.webhook_url', true);
  
  IF webhook_url IS NULL OR webhook_url = '' THEN
    RAISE NOTICE 'Webhook URL not configured';
    RETURN NEW;
  END IF;

  -- إنشاء payload للإشعار
  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'record', row_to_json(NEW),
    'old_record', CASE WHEN TG_OP = 'UPDATE' THEN row_to_json(OLD) ELSE null END
  );

  -- إرسال webhook
  PERFORM net.http_post(
    url := webhook_url,
    body := payload::text,
    headers := '{"Content-Type": "application/json"}'::jsonb
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- دالة للكورسات
CREATE OR REPLACE FUNCTION notify_courses_change()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url text;
  payload jsonb;
  should_send_notification boolean := true;
BEGIN
  -- فحص ما إذا كان التحديث فقط على عمود views
  IF TG_OP = 'UPDATE' THEN
    -- تحقق من أن التغيير ليس فقط على views أو updated_at
    IF NOT (
      OLD.title IS DISTINCT FROM NEW.title OR
      OLD.description IS DISTINCT FROM NEW.description OR
      OLD.price IS DISTINCT FROM NEW.price OR
      OLD.phone IS DISTINCT FROM NEW.phone OR
      OLD.image_url IS DISTINCT FROM NEW.image_url
    ) THEN
      -- فقط views أو updated_at تم تحديثهما - لا نرسل إشعار
      RAISE NOTICE 'Skipping notification - only views or updated_at changed';
      RETURN NEW;
    END IF;
  END IF;

  -- الحصول على webhook URL
  webhook_url := current_setting('app.webhook_url', true);
  
  IF webhook_url IS NULL OR webhook_url = '' THEN
    RAISE NOTICE 'Webhook URL not configured';
    RETURN NEW;
  END IF;

  -- إنشاء payload للإشعار
  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'record', row_to_json(NEW),
    'old_record', CASE WHEN TG_OP = 'UPDATE' THEN row_to_json(OLD) ELSE null END
  );

  -- إرسال webhook
  PERFORM net.http_post(
    url := webhook_url,
    body := payload::text,
    headers := '{"Content-Type": "application/json"}'::jsonb
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ===================================================================
-- 3. إنشاء triggers للكتب والكورسات مع تجاهل تحديثات views
-- ===================================================================

-- حذف triggers القديمة إن وجدت
DROP TRIGGER IF EXISTS trigger_notify_vet_books ON vet_books;
DROP TRIGGER IF EXISTS trigger_notify_vet_courses ON vet_courses;

-- trigger للكتب
CREATE TRIGGER trigger_notify_vet_books
AFTER INSERT OR UPDATE ON vet_books
FOR EACH ROW
EXECUTE FUNCTION notify_books_change();

-- trigger للكورسات
CREATE TRIGGER trigger_notify_vet_courses
AFTER INSERT OR UPDATE ON vet_courses
FOR EACH ROW
EXECUTE FUNCTION notify_courses_change();

-- ===================================================================
-- 4. تحديث الإعدادات الافتراضية للمستخدمين الحاليين
-- ===================================================================

-- تحديث جميع المستخدمين الحاليين ليكون لديهم إشعارات الكتب والكورسات مفعلة
UPDATE notification_preferences 
SET 
  books = COALESCE(books, true),
  courses = COALESCE(courses, true)
WHERE books IS NULL OR courses IS NULL;

-- ===================================================================
-- 5. اختبار التطبيق
-- ===================================================================

-- عرض بعض المعلومات للتأكد من التطبيق
SELECT 
  'Books and Courses notification system installed successfully!' as status,
  'Tables: vet_books, vet_courses' as tables,
  'Triggers: trigger_notify_vet_books, trigger_notify_vet_courses' as triggers,
  'Functions: notify_books_change(), notify_courses_change()' as functions,
  'Preferences: books, courses columns added' as preferences;

-- عرض عدد المستخدمين الذين تم تحديث إعداداتهم
SELECT 
  COUNT(*) as total_users_updated,
  COUNT(CASE WHEN books = true THEN 1 END) as users_with_books_enabled,
  COUNT(CASE WHEN courses = true THEN 1 END) as users_with_courses_enabled
FROM notification_preferences;

-- ===================================================================
-- تم الانتهاء من تطبيق النظام بنجاح! 🎉
-- ===================================================================

/*
الآن يمكنك:
1. إضافة كتاب جديد في جدول vet_books → سيرسل إشعار "📚 كتاب بيطري جديد"
2. تحديث كتاب (غير عمود views) → سيرسل إشعار "📚 تحديث كتاب بيطري"
3. إضافة كورس جديد في جدول vet_courses → سيرسل إشعار "🎓 كورس بيطري جديد"
4. تحديث كورس (غير عمود views) → سيرسل إشعار "🎓 تحديث كورس بيطري"
5. تحديث عمود views فقط → لن يرسل إشعار (محمي!)
6. التحكم في الإشعارات من إعدادات التطبيق
*/