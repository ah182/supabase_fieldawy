-- ============================================================================
-- تفعيل إشعارات التقييمات - نسخة سريعة
-- ============================================================================
-- نفذ هذا الملف في Supabase SQL Editor لتفعيل الإشعارات فوراً
-- ============================================================================

-- 1. تفعيل pg_net extension
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. تعيين webhook URL (استبدل بالـ URL الخاص بك)
-- ALTER DATABASE postgres SET app.settings.webhook_url TO 'https://your-worker.workers.dev';

-- 3. Function لإرسال webhook لطلبات التقييم
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
  v_webhook_url := current_setting('app.settings.webhook_url', true);
  
  IF v_webhook_url IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_webhook_url,
      body := v_payload::text
    );
    
    RAISE NOTICE '📤 webhook sent for new review request: %', v_product_name;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Function لإرسال webhook للتعليقات
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
    
    RAISE NOTICE '📤 webhook sent for new review from: %', v_reviewer_name;
  END IF;

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

-- 6. تأكيد الإعداد
DO $$
DECLARE
  v_webhook_url text;
  v_pg_net_available boolean;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '✅ تم تفعيل إشعارات التقييمات!';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '';
  
  -- التحقق من pg_net
  SELECT EXISTS(
    SELECT 1 FROM pg_available_extensions WHERE name = 'pg_net'
  ) INTO v_pg_net_available;
  
  IF v_pg_net_available THEN
    RAISE NOTICE '✅ pg_net extension: متوفر';
  ELSE
    RAISE NOTICE '❌ pg_net extension: غير متوفر - قم بتفعيله أولاً';
  END IF;
  
  -- التحقق من webhook_url
  v_webhook_url := current_setting('app.settings.webhook_url', true);
  
  IF v_webhook_url IS NOT NULL THEN
    RAISE NOTICE '✅ Webhook URL: %', v_webhook_url;
  ELSE
    RAISE NOTICE '⚠️  Webhook URL: غير معرف';
    RAISE NOTICE '';
    RAISE NOTICE '📝 لتعيين الـ URL، نفذ:';
    RAISE NOTICE 'ALTER DATABASE postgres SET app.settings.webhook_url TO ''https://your-worker.workers.dev'';';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '📋 التالي:';
  RAISE NOTICE '1. تحديث ونشر Cloudflare Worker';
  RAISE NOTICE '2. تعيين webhook_url إذا لم يتم بعد';
  RAISE NOTICE '3. اختبار النظام بإضافة طلب تقييم';
  RAISE NOTICE '';
END $$;
