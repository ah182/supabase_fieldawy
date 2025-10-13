-- ============================================================================
-- فحص مشاكل إشعارات التقييمات
-- ============================================================================

-- 1. التحقق من pg_net extension
DO $$
DECLARE
  v_pg_net_installed boolean;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '🔍 فحص نظام الإشعارات';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '';
  
  -- فحص pg_net
  SELECT EXISTS(
    SELECT 1 FROM pg_extension WHERE extname = 'pg_net'
  ) INTO v_pg_net_installed;
  
  IF v_pg_net_installed THEN
    RAISE NOTICE '✅ pg_net extension: مفعل';
  ELSE
    RAISE WARNING '❌ pg_net extension: غير مفعل!';
    RAISE NOTICE '   👉 لتفعيله: CREATE EXTENSION IF NOT EXISTS pg_net;';
  END IF;
  
  RAISE NOTICE '';
END $$;

-- 2. التحقق من webhook_url
DO $$
DECLARE
  v_webhook_url text;
BEGIN
  BEGIN
    v_webhook_url := current_setting('app.settings.webhook_url', true);
  EXCEPTION WHEN OTHERS THEN
    v_webhook_url := NULL;
  END;
  
  IF v_webhook_url IS NOT NULL AND v_webhook_url <> '' THEN
    RAISE NOTICE '✅ Webhook URL: %', v_webhook_url;
  ELSE
    RAISE WARNING '❌ Webhook URL: غير معرف!';
    RAISE NOTICE '   👉 لتعيينه:';
    RAISE NOTICE '   ALTER DATABASE postgres SET app.settings.webhook_url TO ''https://your-worker.workers.dev'';';
  END IF;
  
  RAISE NOTICE '';
END $$;

-- 3. التحقق من وجود الـ functions
DO $$
DECLARE
  v_func_exists boolean;
BEGIN
  -- فحص notify_new_review_request
  SELECT EXISTS(
    SELECT 1 FROM pg_proc 
    WHERE proname = 'notify_new_review_request'
  ) INTO v_func_exists;
  
  IF v_func_exists THEN
    RAISE NOTICE '✅ Function: notify_new_review_request موجودة';
  ELSE
    RAISE WARNING '❌ Function: notify_new_review_request مفقودة!';
  END IF;
  
  -- فحص notify_new_product_review
  SELECT EXISTS(
    SELECT 1 FROM pg_proc 
    WHERE proname = 'notify_new_product_review'
  ) INTO v_func_exists;
  
  IF v_func_exists THEN
    RAISE NOTICE '✅ Function: notify_new_product_review موجودة';
  ELSE
    RAISE WARNING '❌ Function: notify_new_product_review مفقودة!';
  END IF;
  
  RAISE NOTICE '';
END $$;

-- 4. التحقق من الـ triggers
DO $$
DECLARE
  v_trigger record;
  v_found_requests boolean := false;
  v_found_reviews boolean := false;
BEGIN
  RAISE NOTICE '📋 Triggers الموجودة:';
  RAISE NOTICE '';
  
  FOR v_trigger IN 
    SELECT 
      trigger_name,
      event_manipulation,
      event_object_table,
      action_timing
    FROM information_schema.triggers
    WHERE trigger_name IN (
      'trigger_notify_new_review_request',
      'trigger_notify_new_product_review'
    )
    ORDER BY trigger_name
  LOOP
    RAISE NOTICE '   ✅ %', v_trigger.trigger_name;
    RAISE NOTICE '      Table: %', v_trigger.event_object_table;
    RAISE NOTICE '      Event: % %', v_trigger.action_timing, v_trigger.event_manipulation;
    RAISE NOTICE '';
    
    IF v_trigger.trigger_name = 'trigger_notify_new_review_request' THEN
      v_found_requests := true;
    END IF;
    
    IF v_trigger.trigger_name = 'trigger_notify_new_product_review' THEN
      v_found_reviews := true;
    END IF;
  END LOOP;
  
  IF NOT v_found_requests THEN
    RAISE WARNING '❌ Trigger: trigger_notify_new_review_request مفقود!';
  END IF;
  
  IF NOT v_found_reviews THEN
    RAISE WARNING '❌ Trigger: trigger_notify_new_product_review مفقود!';
  END IF;
  
  RAISE NOTICE '';
END $$;

-- 5. اختبار يدوي للـ function
DO $$
DECLARE
  v_webhook_url text;
  v_test_payload json;
BEGIN
  RAISE NOTICE '🧪 اختبار Function للتعليقات:';
  RAISE NOTICE '';
  
  BEGIN
    v_webhook_url := current_setting('app.settings.webhook_url', true);
  EXCEPTION WHEN OTHERS THEN
    v_webhook_url := NULL;
  END;
  
  IF v_webhook_url IS NULL THEN
    RAISE WARNING '⚠️  لا يمكن الاختبار - webhook_url غير معرف';
  ELSE
    RAISE NOTICE '✅ سيتم الإرسال إلى: %', v_webhook_url;
    
    -- بناء payload تجريبي
    v_test_payload := json_build_object(
      'type', 'INSERT',
      'table', 'product_reviews',
      'record', json_build_object(
        'id', gen_random_uuid(),
        'product_name', 'منتج تجريبي',
        'reviewer_name', 'مستخدم تجريبي',
        'rating', 5,
        'comment', 'تعليق تجريبي للاختبار'
      )
    );
    
    RAISE NOTICE '📦 Payload: %', v_test_payload::text;
    RAISE NOTICE '';
    RAISE NOTICE '💡 لإرسال webhook تجريبي يدوياً:';
    RAISE NOTICE '   SELECT net.http_post(';
    RAISE NOTICE '     url := ''%'',', v_webhook_url;
    RAISE NOTICE '     body := ''%''', v_test_payload::text;
    RAISE NOTICE '   );';
  END IF;
  
  RAISE NOTICE '';
END $$;

-- 6. فحص آخر التعليقات
DO $$
DECLARE
  v_recent_review record;
  v_count int;
BEGIN
  RAISE NOTICE '📊 آخر التعليقات المضافة:';
  RAISE NOTICE '';
  
  SELECT COUNT(*) INTO v_count
  FROM product_reviews
  WHERE created_at >= now() - interval '1 hour';
  
  RAISE NOTICE '   عدد التعليقات في آخر ساعة: %', v_count;
  RAISE NOTICE '';
  
  IF v_count > 0 THEN
    FOR v_recent_review IN 
      SELECT 
        id,
        user_name,
        rating,
        CASE 
          WHEN comment IS NULL OR comment = '' THEN '(بدون تعليق)'
          ELSE substring(comment, 1, 50) || '...'
        END as comment_preview,
        created_at
      FROM product_reviews
      WHERE created_at >= now() - interval '1 hour'
      ORDER BY created_at DESC
      LIMIT 3
    LOOP
      RAISE NOTICE '   • %', v_recent_review.user_name;
      RAISE NOTICE '     Rating: %, Comment: %', 
        v_recent_review.rating,
        v_recent_review.comment_preview;
      RAISE NOTICE '     Created: %', v_recent_review.created_at;
      RAISE NOTICE '';
    END LOOP;
  END IF;
END $$;

-- 7. ملخص نهائي
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '📝 الخطوات التالية:';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '';
  RAISE NOTICE '1. إذا كانت pg_net غير مفعلة:';
  RAISE NOTICE '   CREATE EXTENSION IF NOT EXISTS pg_net;';
  RAISE NOTICE '';
  RAISE NOTICE '2. إذا كانت webhook_url غير معرفة:';
  RAISE NOTICE '   ALTER DATABASE postgres SET app.settings.webhook_url TO ''https://your-worker.workers.dev'';';
  RAISE NOTICE '';
  RAISE NOTICE '3. إذا كانت Functions أو Triggers مفقودة:';
  RAISE NOTICE '   نفذ: FIX_review_notifications_column_name.sql';
  RAISE NOTICE '   ثم: ENSURE_notifications_only_on_insert.sql';
  RAISE NOTICE '';
  RAISE NOTICE '4. تأكد من نشر Cloudflare Worker:';
  RAISE NOTICE '   cd cloudflare-webhook && npx wrangler deploy';
  RAISE NOTICE '';
  RAISE NOTICE '5. اختبر بإضافة تعليق جديد';
  RAISE NOTICE '';
END $$;
