-- ===================================================================
-- إضافة إشعارات لعروض الوظائف والمستلزمات البيطرية
-- ===================================================================
-- هذا الملف يضيف triggers للإشعارات عند إضافة أو تحديث الوظائف والمستلزمات

-- ===================================================================
-- 1. إضافة أعمدة job_offers و vet_supplies لجدول notification_preferences
-- ===================================================================
ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS job_offers BOOLEAN DEFAULT true;

ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS vet_supplies BOOLEAN DEFAULT true;

-- ===================================================================
-- 2. إنشاء دوال triggers لعروض الوظائف والمستلزمات البيطرية
-- ===================================================================

-- دالة لعروض الوظائف
CREATE OR REPLACE FUNCTION notify_job_offers_change()
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

-- دالة للمستلزمات البيطرية
CREATE OR REPLACE FUNCTION notify_vet_supplies_change()
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
-- 3. إنشاء triggers لعروض الوظائف والمستلزمات البيطرية
-- ===================================================================

-- حذف triggers القديمة إن وجدت
DROP TRIGGER IF EXISTS trigger_notify_job_offers ON job_offers;
DROP TRIGGER IF EXISTS trigger_notify_vet_supplies ON vet_supplies;

-- trigger لعروض الوظائف
CREATE TRIGGER trigger_notify_job_offers
AFTER INSERT OR UPDATE ON job_offers
FOR EACH ROW
EXECUTE FUNCTION notify_job_offers_change();

-- trigger للمستلزمات البيطرية
CREATE TRIGGER trigger_notify_vet_supplies
AFTER INSERT OR UPDATE ON vet_supplies
FOR EACH ROW
EXECUTE FUNCTION notify_vet_supplies_change();

-- ===================================================================
-- 4. تحديث الإعدادات الافتراضية للمستخدمين الحاليين
-- ===================================================================

-- تحديث جميع المستخدمين الحاليين ليكون لديهم إشعارات الوظائف والمستلزمات مفعلة
UPDATE notification_preferences 
SET 
  job_offers = COALESCE(job_offers, true),
  vet_supplies = COALESCE(vet_supplies, true)
WHERE job_offers IS NULL OR vet_supplies IS NULL;

-- ===================================================================
-- 5. اختبار التطبيق
-- ===================================================================

-- عرض بعض المعلومات للتأكد من التطبيق
SELECT 
  'Job Offers and Vet Supplies notification system installed successfully!' as status,
  'Tables: job_offers, vet_supplies' as tables,
  'Triggers: trigger_notify_job_offers, trigger_notify_vet_supplies' as triggers,
  'Functions: notify_job_offers_change(), notify_vet_supplies_change()' as functions,
  'Preferences: job_offers, vet_supplies columns added' as preferences;

-- عرض عدد المستخدمين الذين تم تحديث إعداداتهم
SELECT 
  COUNT(*) as total_users_updated,
  COUNT(CASE WHEN job_offers = true THEN 1 END) as users_with_job_offers_enabled,
  COUNT(CASE WHEN vet_supplies = true THEN 1 END) as users_with_vet_supplies_enabled
FROM notification_preferences;

-- ===================================================================
-- تم الانتهاء من تطبيق النظام بنجاح! 🎉
-- ===================================================================

/*
الآن يمكنك:
1. إضافة وظيفة جديدة في جدول job_offers → سيرسل إشعار "💼 وظيفة بيطرية جديدة"
2. تحديث وظيفة (غير عمود views) → سيرسل إشعار "💼 تحديث وظيفة بيطرية"
3. إضافة مستلزم بيطري جديد في جدول vet_supplies → سيرسل إشعار "🏥 مستلزم بيطري جديد"
4. تحديث مستلزم بيطري (غير عمود views) → سيرسل إشعار "🏥 تحديث مستلزم بيطري"
5. تحديث عمود views فقط → لن يرسل إشعار (محمي!)
6. التحكم في الإشعارات من إعدادات التطبيق
7. النقر على إشعار الوظائف → الذهاب لصفحة عروض الوظائف
8. النقر على إشعار المستلزمات → الذهاب لصفحة المستلزمات البيطرية

أمثلة لاختبار النظام:

-- إضافة وظيفة جديدة (سيرسل إشعار)
INSERT INTO job_offers (user_id, job_title, company_name, description, location, salary, phone, email)
VALUES (
  'user-uuid-here',
  'طبيب بيطري',
  'عيادة الرحمة البيطرية',
  'مطلوب طبيب بيطري خبرة 3 سنوات',
  'القاهرة',
  5000.00,
  '+201234567890',
  'info@alrahma-vet.com'
);

-- إضافة مستلزم بيطري جديد (سيرسل إشعار)
INSERT INTO vet_supplies (user_id, name, description, category, price, brand, stock_quantity, phone, email)
VALUES (
  'user-uuid-here',
  'محاقن بيطرية',
  'محاقن عالية الجودة للحيوانات',
  'أدوات طبية',
  25.00,
  'VetCare',
  100,
  '+201234567890',
  'supplies@vetcare.com'
);

-- تحديث views (لن يرسل إشعار!)
UPDATE job_offers SET views = views + 1 WHERE job_title = 'طبيب بيطري';
UPDATE vet_supplies SET views = views + 1 WHERE name = 'محاقن بيطرية';

-- تحديث معلومات مهمة (سيرسل إشعار!)
UPDATE job_offers SET salary = 6000.00 WHERE job_title = 'طبيب بيطري';
UPDATE vet_supplies SET price = 20.00 WHERE name = 'محاقن بيطرية';
*/