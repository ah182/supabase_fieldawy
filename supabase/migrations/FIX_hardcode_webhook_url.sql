-- ============================================================================
-- إصلاح: Hardcode webhook URL في الـ Functions
-- ============================================================================
-- بديل لـ app.settings (لأنه يحتاج صلاحيات superuser)
-- ============================================================================

-- ⚠️ استبدل YOUR_CLOUDFLARE_WORKER_URL بالـ URL الحقيقي!
-- مثال: https://notifications-abc123.workers.dev

-- 1. Function لطلبات التقييم (مع hardcoded URL)
CREATE OR REPLACE FUNCTION notify_new_review_request()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url text := 'https://notification-webhook.ah3181997-1e7.workers.dev';  -- 👈 ضع الـ URL هنا
  v_product_name text;
  v_requester_name text;
  v_payload json;
BEGIN
  -- تحقق من الـ URL
  IF v_webhook_url = 'https://notification-webhook.ah3181997-1e7.workers.dev' OR v_webhook_url IS NULL THEN
    RAISE WARNING 'Webhook URL not configured in function!';
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
  
  RAISE NOTICE '✅ Webhook sent to: %', v_webhook_url;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error sending webhook: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Function للتعليقات (مع hardcoded URL)
CREATE OR REPLACE FUNCTION notify_new_product_review()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url text := 'https://notification-webhook.ah3181997-1e7.workers.dev';  -- 👈 ضع الـ URL هنا
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
    RETURN NEW;
  END IF;

  -- تحقق من الـ URL
  IF v_webhook_url = 'https://notification-webhook.ah3181997-1e7.workers.dev' OR v_webhook_url IS NULL THEN
    RAISE WARNING 'Webhook URL not configured in function!';
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
  
  RAISE NOTICE '✅ Webhook sent for review: % by %', v_product_name, v_reviewer_name;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error sending webhook: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. إنشاء/تحديث الـ Triggers
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

-- 4. رسالة
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  تذكير مهم!';
  RAISE NOTICE '📝 لازم تعدل الـ URL في الملف:';
  RAISE NOTICE '   ابحث عن: YOUR_CLOUDFLARE_WORKER_URL';
  RAISE NOTICE '   واستبدله بـ: https://your-worker.workers.dev';
  RAISE NOTICE '';
  RAISE NOTICE '💡 أو استخدم Supabase Database Webhooks من Dashboard!';
  RAISE NOTICE '';
END $$;
