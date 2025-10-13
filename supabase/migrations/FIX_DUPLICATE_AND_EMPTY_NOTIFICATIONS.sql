-- ============================================================================
-- إصلاح الإشعارات المكررة والفارغة
-- ============================================================================

-- 1. حذف كل الـ triggers القديمة
DO $$
BEGIN
  RAISE NOTICE '1️⃣ حذف الـ Triggers القديمة...';
  RAISE NOTICE '';
END $$;

DROP TRIGGER IF EXISTS trigger_notify_new_review_request ON review_requests CASCADE;
DROP TRIGGER IF EXISTS trigger_notify_new_product_review ON product_reviews CASCADE;

-- حذف أي triggers مكررة محتملة
DROP TRIGGER IF EXISTS notify_review_request ON review_requests CASCADE;
DROP TRIGGER IF EXISTS notify_product_review ON product_reviews CASCADE;

-- 2. حذف الـ functions القديمة
DROP FUNCTION IF EXISTS notify_new_review_request() CASCADE;
DROP FUNCTION IF EXISTS notify_new_product_review() CASCADE;

-- 3. إنشاء function جديدة لطلبات التقييم (بدون تكرار)
CREATE OR REPLACE FUNCTION notify_new_review_request()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url text := 'https://notification-webhook.ah3181997-1e7.workers.dev';
  v_product_name text;
  v_requester_name text;
  v_payload json;
BEGIN
  -- تجاهل UPDATE/DELETE
  IF TG_OP != 'INSERT' THEN
    RETURN NEW;
  END IF;

  -- تحقق من الـ URL
  IF v_webhook_url IS NULL OR v_webhook_url = 'YOUR_CLOUDFLARE_WORKER_URL' THEN
    RAISE WARNING 'Webhook URL not configured!';
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
      'requested_by', NEW.requested_by,
      'created_at', NEW.created_at
    )
  );

  -- إرسال webhook
  PERFORM net.http_post(
    url := v_webhook_url,
    body := v_payload::text
  );
  
  RAISE NOTICE '✅ Review request webhook sent: %', NEW.id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error sending webhook: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. إنشاء function جديدة للتعليقات (مع منع الإشعارات الفارغة)
CREATE OR REPLACE FUNCTION notify_new_product_review()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url text := 'https://notification-webhook.ah3181997-1e7.workers.dev';
  v_product_name text;
  v_reviewer_name text;
  v_comment_preview text;
  v_payload json;
BEGIN
  -- ✅ فقط INSERT
  IF TG_OP != 'INSERT' THEN
    RETURN NEW;
  END IF;

  -- ✅ ✅ ✅ IMPORTANT: تجاهل التقييمات بدون تعليق!
  IF NEW.comment IS NULL OR trim(NEW.comment) = '' THEN
    RAISE NOTICE '⏭️ Skipping notification - no comment (review: %)', NEW.id;
    RETURN NEW;
  END IF;

  -- تحقق من الـ URL
  IF v_webhook_url IS NULL OR v_webhook_url = 'YOUR_CLOUDFLARE_WORKER_URL' THEN
    RAISE WARNING 'Webhook URL not configured!';
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
  
  RAISE NOTICE '✅ Product review webhook sent: % by %', v_product_name, v_reviewer_name;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error sending webhook: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. إنشاء triggers جديدة (واحدة فقط لكل جدول)
CREATE TRIGGER trigger_notify_new_review_request
AFTER INSERT ON review_requests
FOR EACH ROW
EXECUTE FUNCTION notify_new_review_request();

CREATE TRIGGER trigger_notify_new_product_review
AFTER INSERT ON product_reviews
FOR EACH ROW
WHEN (NEW.comment IS NOT NULL AND trim(NEW.comment) <> '')
EXECUTE FUNCTION notify_new_product_review();

-- 6. التحقق من النتيجة
DO $$
DECLARE
  v_trigger record;
  v_count int := 0;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ تم إصلاح النظام!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  
  RAISE NOTICE '📋 Triggers النهائية:';
  RAISE NOTICE '';
  
  FOR v_trigger IN 
    SELECT 
      trigger_name,
      event_object_table,
      event_manipulation
    FROM information_schema.triggers
    WHERE trigger_name LIKE '%notify%'
    ORDER BY event_object_table, trigger_name
  LOOP
    v_count := v_count + 1;
    RAISE NOTICE '   %d. % (%)', v_count, v_trigger.trigger_name, v_trigger.event_object_table;
  END LOOP;
  
  IF v_count = 2 THEN
    RAISE NOTICE '';
    RAISE NOTICE '✅ عدد الـ Triggers صحيح (2)';
  ELSIF v_count > 2 THEN
    RAISE WARNING '⚠️  عدد الـ Triggers أكثر من المتوقع: %', v_count;
    RAISE NOTICE '   قد يسبب تكرار الإشعارات!';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '🚫 الإشعارات لن تُرسل عند:';
  RAISE NOTICE '   - تقييم بدون تعليق (نجوم فقط)';
  RAISE NOTICE '   - تحديث تقييم';
  RAISE NOTICE '   - حذف تقييم';
  RAISE NOTICE '';
  RAISE NOTICE '✅ الإشعارات ستُرسل فقط عند:';
  RAISE NOTICE '   - إضافة طلب تقييم جديد';
  RAISE NOTICE '   - إضافة تعليق نصي جديد';
  RAISE NOTICE '';
  RAISE NOTICE '📝 الخطوة التالية:';
  RAISE NOTICE '   👉 اذهب لـ Database → Webhooks في Dashboard';
  RAISE NOTICE '   👉 احذف reviewrequests و productreviews';
  RAISE NOTICE '   👉 اترك SQL Triggers فقط';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  
END $$;
