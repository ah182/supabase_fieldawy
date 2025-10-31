-- ===================================================================
-- إضافة إشعارات للكتب والكورسات
-- ===================================================================
-- هذا الملف يضيف triggers للإشعارات عند إضافة أو تحديث الكتب والكورسات

-- ===================================================================
-- 1. إضافة trigger للكتب (vet_books)
-- ===================================================================
CREATE OR REPLACE FUNCTION notify_books_change()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url text;
  payload jsonb;
BEGIN
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

-- إنشاء trigger للكتب مع تجاهل تحديثات views فقط
CREATE TRIGGER trigger_notify_vet_books
AFTER INSERT OR UPDATE ON vet_books
FOR EACH ROW
WHEN (
  -- للإدراج الجديد: إرسال دائماً
  TG_OP = 'INSERT' OR 
  -- للتحديث: إرسال فقط إذا تغير شيء غير views و updated_at
  (TG_OP = 'UPDATE' AND (
    OLD.name IS DISTINCT FROM NEW.name OR
    OLD.author IS DISTINCT FROM NEW.author OR
    OLD.description IS DISTINCT FROM NEW.description OR
    OLD.price IS DISTINCT FROM NEW.price OR
    OLD.phone IS DISTINCT FROM NEW.phone OR
    OLD.image_url IS DISTINCT FROM NEW.image_url
  ))
)
EXECUTE FUNCTION notify_books_change();

-- ===================================================================
-- 2. إضافة trigger للكورسات (vet_courses)
-- ===================================================================
CREATE OR REPLACE FUNCTION notify_courses_change()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url text;
  payload jsonb;
BEGIN
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

-- إنشاء trigger للكورسات مع تجاهل تحديثات views فقط
CREATE TRIGGER trigger_notify_vet_courses
AFTER INSERT OR UPDATE ON vet_courses
FOR EACH ROW
WHEN (
  -- للإدراج الجديد: إرسال دائماً
  TG_OP = 'INSERT' OR 
  -- للتحديث: إرسال فقط إذا تغير شيء غير views و updated_at
  (TG_OP = 'UPDATE' AND (
    OLD.title IS DISTINCT FROM NEW.title OR
    OLD.description IS DISTINCT FROM NEW.description OR
    OLD.price IS DISTINCT FROM NEW.price OR
    OLD.phone IS DISTINCT FROM NEW.phone OR
    OLD.image_url IS DISTINCT FROM NEW.image_url
  ))
)
EXECUTE FUNCTION notify_courses_change();

-- ===================================================================
-- 3. إضافة أعمدة الكتب والكورسات لجدول notification_preferences
-- ===================================================================
-- إضافة عمود للكتب
ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS books BOOLEAN DEFAULT true;

-- إضافة عمود للكورسات
ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS courses BOOLEAN DEFAULT true;

-- ===================================================================
-- تم الانتهاء من إعداد إشعارات الكتب والكورسات
-- ===================================================================