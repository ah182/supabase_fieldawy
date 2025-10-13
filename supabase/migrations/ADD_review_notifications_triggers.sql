-- ============================================================================
-- إشعارات التقييمات - Triggers & Webhooks
-- ============================================================================
-- يرسل إشعار لجميع المستخدمين عند:
-- 1. إضافة طلب تقييم جديد (review_requests)
-- 2. إضافة تعليق جديد (product_reviews)
-- ============================================================================

-- 1. Function لإرسال webhook لطلبات التقييم
CREATE OR REPLACE FUNCTION notify_new_review_request()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url text;
  v_product_name text;
  v_requester_name text;
  v_payload json;
BEGIN
  -- جلب معلومات المنتج
  IF NEW.product_type = 'product' THEN
    SELECT name INTO v_product_name
    FROM products
    WHERE id::text = NEW.product_id
    LIMIT 1;
  ELSIF NEW.product_type = 'ocr_product' THEN
    SELECT product_name INTO v_product_name
    FROM ocr_products
    WHERE id::text = NEW.product_id
    LIMIT 1;
  ELSIF NEW.product_type = 'surgical_tool' THEN
    SELECT tool_name INTO v_product_name
    FROM surgical_tools
    WHERE id::text = NEW.product_id
    LIMIT 1;
  END IF;

  -- جلب اسم صاحب الطلب
  SELECT COALESCE(display_name, email, 'مستخدم')
  INTO v_requester_name
  FROM users
  WHERE id = NEW.user_id
  LIMIT 1;

  -- بناء الـ payload
  v_payload := json_build_object(
    'type', 'INSERT',
    'table', 'review_requests',
    'record', json_build_object(
      'id', NEW.id,
      'product_id', NEW.product_id,
      'product_type', NEW.product_type,
      'product_name', COALESCE(v_product_name, 'منتج'),
      'requester_name', COALESCE(v_requester_name, 'مستخدم'),
      'user_id', NEW.user_id,
      'created_at', NEW.created_at
    )
  );

  -- إرسال الـ webhook
  -- استبدل بـ URL الـ Cloudflare Worker الخاص بك
  v_webhook_url := current_setting('app.settings.webhook_url', true);
  
  IF v_webhook_url IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_webhook_url,
      body := v_payload::text
    );
    
    RAISE NOTICE '📤 تم إرسال webhook لطلب تقييم جديد: %', v_product_name;
  ELSE
    RAISE NOTICE '⚠️ webhook_url غير معرف في app.settings';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Function لإرسال webhook للتعليقات
CREATE OR REPLACE FUNCTION notify_new_product_review()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url text;
  v_product_name text;
  v_reviewer_name text;
  v_comment_preview text;
  v_payload json;
BEGIN
  -- تجاهل التحديثات، فقط للإضافات الجديدة
  IF TG_OP = 'UPDATE' THEN
    RETURN NEW;
  END IF;

  -- تجاهل لو مفيش تعليق
  IF NEW.comment IS NULL OR NEW.comment = '' THEN
    RETURN NEW;
  END IF;

  -- جلب اسم المنتج من review_requests
  SELECT product_name INTO v_product_name
  FROM review_requests
  WHERE id = NEW.review_request_id
  LIMIT 1;

  -- جلب اسم المعلق
  SELECT COALESCE(display_name, email, 'مستخدم')
  INTO v_reviewer_name
  FROM users
  WHERE id = NEW.user_id
  LIMIT 1;

  -- معاينة التعليق (أول 100 حرف)
  v_comment_preview := CASE 
    WHEN length(NEW.comment) > 100 THEN substring(NEW.comment, 1, 100) || '...'
    ELSE NEW.comment
  END;

  -- بناء الـ payload
  v_payload := json_build_object(
    'type', 'INSERT',
    'table', 'product_reviews',
    'record', json_build_object(
      'id', NEW.id,
      'review_request_id', NEW.review_request_id,
      'product_id', NEW.product_id,
      'product_type', NEW.product_type,
      'product_name', COALESCE(v_product_name, 'منتج'),
      'reviewer_name', COALESCE(v_reviewer_name, 'مستخدم'),
      'rating', NEW.rating,
      'comment', v_comment_preview,
      'user_id', NEW.user_id,
      'created_at', NEW.created_at
    )
  );

  -- إرسال الـ webhook
  v_webhook_url := current_setting('app.settings.webhook_url', true);
  
  IF v_webhook_url IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_webhook_url,
      body := v_payload::text
    );
    
    RAISE NOTICE '📤 تم إرسال webhook لتعليق جديد من: %', v_reviewer_name;
  ELSE
    RAISE NOTICE '⚠️ webhook_url غير معرف في app.settings';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. إنشاء الـ Triggers
DROP TRIGGER IF EXISTS trigger_notify_new_review_request ON review_requests;
CREATE TRIGGER trigger_notify_new_review_request
AFTER INSERT ON review_requests
FOR EACH ROW
EXECUTE FUNCTION notify_new_review_request();

DROP TRIGGER IF EXISTS trigger_notify_new_product_review ON product_reviews;
CREATE TRIGGER trigger_notify_new_product_review
AFTER INSERT ON product_reviews
FOR EACH ROW
WHEN (NEW.comment IS NOT NULL AND NEW.comment <> '')
EXECUTE FUNCTION notify_new_product_review();

-- 4. إعداد الـ webhook URL (اختياري - يمكن تعيينه لاحقاً)
-- استبدل YOUR_CLOUDFLARE_WORKER_URL بـ URL الـ worker الخاص بك
-- ALTER DATABASE postgres SET app.settings.webhook_url TO 'https://your-worker.workers.dev';

-- 5. رسالة تأكيد
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ تم إنشاء triggers إشعارات التقييمات!';
  RAISE NOTICE '';
  RAISE NOTICE '📋 التالي:';
  RAISE NOTICE '1. تحديث Cloudflare Worker ليدعم review_requests و product_reviews';
  RAISE NOTICE '2. تعيين webhook_url في إعدادات قاعدة البيانات';
  RAISE NOTICE '3. التأكد من تفعيل pg_net extension';
  RAISE NOTICE '';
  RAISE NOTICE '💡 لتعيين الـ webhook URL:';
  RAISE NOTICE 'ALTER DATABASE postgres SET app.settings.webhook_url TO ''https://your-worker.workers.dev'';';
  RAISE NOTICE '';
END $$;
