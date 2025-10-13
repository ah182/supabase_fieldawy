-- ============================================================================
-- تفعيل الإشعارات بسرعة
-- ============================================================================

-- 1. تفعيل pg_net (ضروري لإرسال HTTP requests)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. تعيين webhook URL
-- ⚠️ استبدل YOUR_CLOUDFLARE_WORKER_URL بالـ URL الحقيقي!
-- مثال: https://notifications-abc123.workers.dev
-- ALTER DATABASE postgres SET app.settings.webhook_url TO 'YOUR_CLOUDFLARE_WORKER_URL';

-- 3. الـ Function لطلبات التقييم
CREATE OR REPLACE FUNCTION notify_new_review_request()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url text;
  v_product_name text;
  v_requester_name text;
  v_payload json;
BEGIN
  -- جلب webhook URL
  BEGIN
    v_webhook_url := current_setting('app.settings.webhook_url', true);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'webhook_url not configured';
    RETURN NEW;
  END;
  
  IF v_webhook_url IS NULL OR v_webhook_url = '' THEN
    RAISE WARNING 'webhook_url is empty';
    RETURN NEW;
  END IF;

  -- جلب اسم المنتج
  IF NEW.product_type = 'product' THEN
    SELECT name INTO v_product_name FROM products WHERE id::text = NEW.product_id LIMIT 1;
  ELSIF NEW.product_type = 'ocr_product' THEN
    SELECT product_name INTO v_product_name FROM ocr_products WHERE id::text = NEW.product_id LIMIT 1;
  ELSIF NEW.product_type = 'surgical_tool' THEN
    SELECT tool_name INTO v_product_name FROM surgical_tools WHERE id::text = NEW.product_id LIMIT 1;
  END IF;

  -- جلب اسم صاحب الطلب
  SELECT COALESCE(display_name, email, 'مستخدم')
  INTO v_requester_name
  FROM users
  WHERE id = NEW.requested_by
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
      'user_id', NEW.requested_by,
      'created_at', NEW.created_at
    )
  );

  -- إرسال webhook
  PERFORM net.http_post(
    url := v_webhook_url,
    body := v_payload::text
  );
  
  RAISE NOTICE '✅ Webhook sent for review_request: %', NEW.id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error sending webhook: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. الـ Function للتعليقات
CREATE OR REPLACE FUNCTION notify_new_product_review()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url text;
  v_product_name text;
  v_reviewer_name text;
  v_comment_preview text;
  v_payload json;
BEGIN
  -- فقط INSERT
  IF TG_OP != 'INSERT' THEN
    RETURN NEW;
  END IF;

  -- فقط لو فيه تعليق
  IF NEW.comment IS NULL OR NEW.comment = '' THEN
    RAISE NOTICE 'No comment - skipping notification';
    RETURN NEW;
  END IF;

  -- جلب webhook URL
  BEGIN
    v_webhook_url := current_setting('app.settings.webhook_url', true);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'webhook_url not configured';
    RETURN NEW;
  END;
  
  IF v_webhook_url IS NULL OR v_webhook_url = '' THEN
    RAISE WARNING 'webhook_url is empty';
    RETURN NEW;
  END IF;

  -- جلب اسم المنتج
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

  -- معاينة التعليق
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

  -- إرسال webhook
  PERFORM net.http_post(
    url := v_webhook_url,
    body := v_payload::text
  );
  
  RAISE NOTICE '✅ Webhook sent for product_review: %', NEW.id;
  RAISE NOTICE '   Product: %, Reviewer: %', v_product_name, v_reviewer_name;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING '❌ Error sending webhook: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. إنشاء الـ Triggers
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

-- 6. اختبار الإعداد
DO $$
DECLARE
  v_pg_net boolean;
  v_webhook_url text;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '✅ تم تفعيل النظام!';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '';
  
  -- فحص pg_net
  SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_net') INTO v_pg_net;
  
  IF v_pg_net THEN
    RAISE NOTICE '✅ pg_net: مفعل';
  ELSE
    RAISE WARNING '❌ pg_net: غير مفعل - قم بتفعيله يدوياً';
  END IF;
  
  -- فحص webhook_url
  BEGIN
    v_webhook_url := current_setting('app.settings.webhook_url', true);
  EXCEPTION WHEN OTHERS THEN
    v_webhook_url := NULL;
  END;
  
  IF v_webhook_url IS NOT NULL AND v_webhook_url <> '' THEN
    RAISE NOTICE '✅ Webhook URL: %', v_webhook_url;
  ELSE
    RAISE WARNING '❌ Webhook URL: غير معرف!';
    RAISE NOTICE '';
    RAISE NOTICE '👉 لتعيينه، نفذ:';
    RAISE NOTICE 'ALTER DATABASE postgres SET app.settings.webhook_url TO ''https://your-worker.workers.dev'';';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '🧪 الآن جرب إضافة تعليق جديد!';
  RAISE NOTICE '';
END $$;
