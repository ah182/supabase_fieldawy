-- ===================================================================
-- نشر نظام الإشعارات الكامل - تطبيق جميع التحديثات
-- ===================================================================
-- هذا الـ script النهائي يطبق جميع التحديثات للكتب والكورسات والوظائف والمستلزمات

-- ===================================================================
-- 1. إضافة جميع الأعمدة الجديدة لجدول notification_preferences
-- ===================================================================
ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS books BOOLEAN DEFAULT true;

ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS courses BOOLEAN DEFAULT true;

ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS job_offers BOOLEAN DEFAULT true;

ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS vet_supplies BOOLEAN DEFAULT true;

-- ===================================================================
-- 2. إنشاء دوال triggers لجميع الجداول الجديدة
-- ===================================================================

-- دالة للكتب
CREATE OR REPLACE FUNCTION notify_books_change()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url text;
  payload jsonb;
BEGIN
  -- فحص ما إذا كان التحديث فقط على عمود views
  IF TG_OP = 'UPDATE' THEN
    IF NOT (
      OLD.name IS DISTINCT FROM NEW.name OR
      OLD.author IS DISTINCT FROM NEW.author OR
      OLD.description IS DISTINCT FROM NEW.description OR
      OLD.price IS DISTINCT FROM NEW.price OR
      OLD.phone IS DISTINCT FROM NEW.phone OR
      OLD.image_url IS DISTINCT FROM NEW.image_url
    ) THEN
      RAISE NOTICE 'Skipping notification - only views or updated_at changed';
      RETURN NEW;
    END IF;
  END IF;

  webhook_url := current_setting('app.webhook_url', true);
  IF webhook_url IS NULL OR webhook_url = '' THEN
    RAISE NOTICE 'Webhook URL not configured';
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'record', row_to_json(NEW),
    'old_record', CASE WHEN TG_OP = 'UPDATE' THEN row_to_json(OLD) ELSE null END
  );

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
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NOT (
      OLD.title IS DISTINCT FROM NEW.title OR
      OLD.description IS DISTINCT FROM NEW.description OR
      OLD.price IS DISTINCT FROM NEW.price OR
      OLD.phone IS DISTINCT FROM NEW.phone OR
      OLD.image_url IS DISTINCT FROM NEW.image_url
    ) THEN
      RAISE NOTICE 'Skipping notification - only views or updated_at changed';
      RETURN NEW;
    END IF;
  END IF;

  webhook_url := current_setting('app.webhook_url', true);
  IF webhook_url IS NULL OR webhook_url = '' THEN
    RAISE NOTICE 'Webhook URL not configured';
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'record', row_to_json(NEW),
    'old_record', CASE WHEN TG_OP = 'UPDATE' THEN row_to_json(OLD) ELSE null END
  );

  PERFORM net.http_post(
    url := webhook_url,
    body := payload::text,
    headers := '{"Content-Type": "application/json"}'::jsonb
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- دالة لعروض الوظائف
CREATE OR REPLACE FUNCTION notify_job_offers_change()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url text;
  payload jsonb;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NOT (
      OLD.job_title IS DISTINCT FROM NEW.job_title OR
      OLD.company_name IS DISTINCT FROM NEW.company_name OR
      OLD.description IS DISTINCT FROM NEW.description OR
      OLD.salary IS DISTINCT FROM NEW.salary OR
      OLD.location IS DISTINCT FROM NEW.location OR
      OLD.employment_type IS DISTINCT FROM NEW.employment_type OR
      OLD.requirements IS DISTINCT FROM NEW.requirements OR
      OLD.phone IS DISTINCT FROM NEW.phone OR
      OLD.email IS DISTINCT FROM NEW.email OR
      OLD.status IS DISTINCT FROM NEW.status
    ) THEN
      RAISE NOTICE 'Skipping notification - only views or updated_at changed';
      RETURN NEW;
    END IF;
  END IF;

  webhook_url := current_setting('app.webhook_url', true);
  IF webhook_url IS NULL OR webhook_url = '' THEN
    RAISE NOTICE 'Webhook URL not configured';
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'record', row_to_json(NEW),
    'old_record', CASE WHEN TG_OP = 'UPDATE' THEN row_to_json(OLD) ELSE null END
  );

  PERFORM net.http_post(
    url := webhook_url,
    body := payload::text,
    headers := '{"Content-Type": "application/json"}'::jsonb
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- دالة للمستلزمات البيطرية
CREATE OR REPLACE FUNCTION notify_vet_supplies_change()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url text;
  payload jsonb;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NOT (
      OLD.name IS DISTINCT FROM NEW.name OR
      OLD.description IS DISTINCT FROM NEW.description OR
      OLD.price IS DISTINCT FROM NEW.price OR
      OLD.category IS DISTINCT FROM NEW.category OR
      OLD.brand IS DISTINCT FROM NEW.brand OR
      OLD.stock_quantity IS DISTINCT FROM NEW.stock_quantity OR
      OLD.phone IS DISTINCT FROM NEW.phone OR
      OLD.email IS DISTINCT FROM NEW.email OR
      OLD.image_url IS DISTINCT FROM NEW.image_url OR
      OLD.status IS DISTINCT FROM NEW.status
    ) THEN
      RAISE NOTICE 'Skipping notification - only views or updated_at changed';
      RETURN NEW;
    END IF;
  END IF;

  webhook_url := current_setting('app.webhook_url', true);
  IF webhook_url IS NULL OR webhook_url = '' THEN
    RAISE NOTICE 'Webhook URL not configured';
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'record', row_to_json(NEW),
    'old_record', CASE WHEN TG_OP = 'UPDATE' THEN row_to_json(OLD) ELSE null END
  );

  PERFORM net.http_post(
    url := webhook_url,
    body := payload::text,
    headers := '{"Content-Type": "application/json"}'::jsonb
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ===================================================================
-- 3. إنشاء جميع triggers
-- ===================================================================

-- حذف triggers القديمة إن وجدت
DROP TRIGGER IF EXISTS trigger_notify_vet_books ON vet_books;
DROP TRIGGER IF EXISTS trigger_notify_vet_courses ON vet_courses;
DROP TRIGGER IF EXISTS trigger_notify_job_offers ON job_offers;
DROP TRIGGER IF EXISTS trigger_notify_vet_supplies ON vet_supplies;

-- إنشاء triggers جديدة
CREATE TRIGGER trigger_notify_vet_books
AFTER INSERT OR UPDATE ON vet_books
FOR EACH ROW
EXECUTE FUNCTION notify_books_change();

CREATE TRIGGER trigger_notify_vet_courses
AFTER INSERT OR UPDATE ON vet_courses
FOR EACH ROW
EXECUTE FUNCTION notify_courses_change();

CREATE TRIGGER trigger_notify_job_offers
AFTER INSERT OR UPDATE ON job_offers
FOR EACH ROW
EXECUTE FUNCTION notify_job_offers_change();

CREATE TRIGGER trigger_notify_vet_supplies
AFTER INSERT OR UPDATE ON vet_supplies
FOR EACH ROW
EXECUTE FUNCTION notify_vet_supplies_change();

-- ===================================================================
-- 4. تحديث الإعدادات الافتراضية للمستخدمين الحاليين
-- ===================================================================

UPDATE notification_preferences 
SET 
  books = COALESCE(books, true),
  courses = COALESCE(courses, true),
  job_offers = COALESCE(job_offers, true),
  vet_supplies = COALESCE(vet_supplies, true)
WHERE books IS NULL OR courses IS NULL OR job_offers IS NULL OR vet_supplies IS NULL;

-- ===================================================================
-- 5. تقرير التطبيق النهائي
-- ===================================================================

SELECT 
  '🎉 نظام الإشعارات الكامل تم تطبيقه بنجاح!' as status,
  'vet_books, vet_courses, job_offers, vet_supplies' as tables_covered,
  '4 triggers created successfully' as triggers_status,
  '4 notification functions created' as functions_status,
  '4 new preference columns added' as preferences_status;

-- عرض إحصائيات المستخدمين
SELECT 
  COUNT(*) as total_users,
  COUNT(CASE WHEN books = true THEN 1 END) as books_enabled,
  COUNT(CASE WHEN courses = true THEN 1 END) as courses_enabled,
  COUNT(CASE WHEN job_offers = true THEN 1 END) as job_offers_enabled,
  COUNT(CASE WHEN vet_supplies = true THEN 1 END) as vet_supplies_enabled
FROM notification_preferences;

-- ===================================================================
-- 🚀 النظام جاهز للاستخدام!
-- ===================================================================

/*
✅ ما تم تطبيقه:

1. 📚 إشعارات الكتب البيطرية:
   - إضافة كتاب جديد → "📚 كتاب بيطري جديد: اسم الكتاب\nبواسطة المؤلف"
   - تحديث كتاب → "📚 تحديث كتاب بيطري"
   - النقر → الذهاب لتاب الكتب (index 5)

2. 🎓 إشعارات الكورسات البيطرية:
   - إضافة كورس جديد → "🎓 كورس بيطري جديد: عنوان الكورس"
   - تحديث كورس → "🎓 تحديث كورس بيطري"
   - النقر → الذهاب لتاب الكورسات (index 6)

3. 💼 إشعارات عروض الوظائف:
   - إضافة وظيفة جديدة → "💼 وظيفة بيطرية جديدة: عنوان الوظيفة\nالشركة - الموقع"
   - تحديث وظيفة → "💼 تحديث وظيفة بيطرية"
   - النقر → الذهاب لصفحة عروض الوظائف

4. 🏥 إشعارات المستلزمات البيطرية:
   - إضافة مستلزم جديد → "🏥 مستلزم بيطري جديد: اسم المستلزم\nفئة: الفئة"
   - تحديث مستلزم → "🏥 تحديث مستلزم بيطري"
   - النقر → الذهاب لصفحة المستلزمات البيطرية

5. 🔧 إعدادات الإشعارات:
   - 4 توجل جديدة في شاشة الإعدادات
   - إمكانية تفعيل/إلغاء كل نوع منفصل
   - حفظ تلقائي للتفضيلات

6. 🛡️ الحماية من الإزعاج:
   - تحديث عمود views فقط → لا يرسل إشعار
   - تحديث أي حقل آخر → يرسل إشعار

الخطوات التالية:
1. تشغيل هذا الـ script في Supabase
2. نشر Cloudflare Worker المحدث
3. تحديث Flutter app
4. اختبار النظام!
*/