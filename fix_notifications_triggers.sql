-- ===================================================================
-- إصلاح triggers الإشعارات للوظائف والمستلزمات البيطرية
-- ===================================================================
-- هذا الملف يصحح أسماء الحقول في triggers الإشعارات

-- ===================================================================
-- 1. إصلاح دالة إشعارات الوظائف
-- ===================================================================

CREATE OR REPLACE FUNCTION notify_job_offers_change()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url text;
  payload jsonb;
BEGIN
  -- فحص ما إذا كان التحديث فقط على عمود views_count
  IF TG_OP = 'UPDATE' THEN
    IF NOT (
      OLD.title IS DISTINCT FROM NEW.title OR
      OLD.description IS DISTINCT FROM NEW.description OR
      OLD.phone IS DISTINCT FROM NEW.phone OR
      OLD.status IS DISTINCT FROM NEW.status
    ) THEN
      -- فقط views_count أو updated_at تم تحديثهما - لا نرسل إشعار
      RAISE NOTICE 'Skipping notification - only views_count or updated_at changed';
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
-- 2. إصلاح دالة إشعارات المستلزمات البيطرية
-- ===================================================================

CREATE OR REPLACE FUNCTION notify_vet_supplies_change()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url text;
  payload jsonb;
BEGIN
  -- فحص ما إذا كان التحديث فقط على عمود views_count
  IF TG_OP = 'UPDATE' THEN
    IF NOT (
      OLD.name IS DISTINCT FROM NEW.name OR
      OLD.description IS DISTINCT FROM NEW.description OR
      OLD.price IS DISTINCT FROM NEW.price OR
      OLD.image_url IS DISTINCT FROM NEW.image_url OR
      OLD.phone IS DISTINCT FROM NEW.phone OR
      OLD.status IS DISTINCT FROM NEW.status
    ) THEN
      -- فقط views_count أو updated_at تم تحديثهما - لا نرسل إشعار
      RAISE NOTICE 'Skipping notification - only views_count or updated_at changed';
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
-- 3. إعادة إنشاء triggers مع الدوال المصححة
-- ===================================================================

-- حذف triggers القديمة
DROP TRIGGER IF EXISTS trigger_notify_job_offers ON job_offers;
DROP TRIGGER IF EXISTS trigger_notify_vet_supplies ON vet_supplies;

-- إنشاء triggers جديدة
CREATE TRIGGER trigger_notify_job_offers
AFTER INSERT OR UPDATE ON job_offers
FOR EACH ROW
EXECUTE FUNCTION notify_job_offers_change();

CREATE TRIGGER trigger_notify_vet_supplies
AFTER INSERT OR UPDATE ON vet_supplies
FOR EACH ROW
EXECUTE FUNCTION notify_vet_supplies_change();

-- ===================================================================
-- 4. تأكيد الإصلاح
-- ===================================================================

SELECT 
  'تم إصلاح triggers الإشعارات بنجاح!' as status,
  'job_offers: title, description, phone, status' as job_offers_fields,
  'vet_supplies: name, description, price, image_url, phone, status' as vet_supplies_fields,
  'views_count updates will be ignored' as protection;

-- ===================================================================
-- تم الانتهاء من الإصلاح! 🎉
-- ===================================================================

/*
✅ ما تم إصلاحه:

1. 💼 إشعارات الوظائف:
   - الحقول الصحيحة: title, description, phone, status
   - تجاهل تحديثات: views_count, updated_at
   - إزالة الحقول غير الموجودة: job_title, company_name, location, salary, etc.

2. 🏥 إشعارات المستلزمات:
   - الحقول الصحيحة: name, description, price, image_url, phone, status
   - تجاهل تحديثات: views_count, updated_at
   - إزالة الحقول غير الموجودة: category, brand, stock_quantity, email, etc.

🧪 اختبار الإصلاح:

-- ✅ سيرسل إشعار (تحديث title)
UPDATE job_offers SET title = 'عنوان جديد' WHERE id = 'job-id';

-- ✅ سيرسل إشعار (تحديث price)
UPDATE vet_supplies SET price = 50.00 WHERE id = 'supply-id';

-- ❌ لن يرسل إشعار (تحديث views_count فقط - محمي!)
UPDATE job_offers SET views_count = views_count + 1 WHERE id = 'job-id';
UPDATE vet_supplies SET views_count = views_count + 1 WHERE id = 'supply-id';

الآن Triggers ستعمل بدون أخطاء!
*/