-- ============================================================================
-- فحص شامل لنظام الإشعارات
-- ============================================================================

DO $$
DECLARE
  v_pg_net boolean;
  v_webhook_url text;
  v_function_exists boolean;
  v_trigger record;
  v_recent_review record;
  v_test_result text;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 فحص شامل لنظام الإشعارات';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  
  -- ============================================================
  -- 1. فحص pg_net extension
  -- ============================================================
  RAISE NOTICE '1️⃣ فحص pg_net Extension:';
  RAISE NOTICE '----------------------------------------';
  
  SELECT EXISTS(
    SELECT 1 FROM pg_extension WHERE extname = 'pg_net'
  ) INTO v_pg_net;
  
  IF v_pg_net THEN
    RAISE NOTICE '   ✅ pg_net: مفعل';
  ELSE
    RAISE NOTICE '   ❌ pg_net: غير مفعل!';
    RAISE NOTICE '   👉 نفذ: CREATE EXTENSION IF NOT EXISTS pg_net;';
  END IF;
  RAISE NOTICE '';
  
  -- ============================================================
  -- 2. فحص الـ Functions
  -- ============================================================
  RAISE NOTICE '2️⃣ فحص الـ Functions:';
  RAISE NOTICE '----------------------------------------';
  
  -- Function للتعليقات
  SELECT EXISTS(
    SELECT 1 FROM pg_proc WHERE proname = 'notify_new_product_review'
  ) INTO v_function_exists;
  
  IF v_function_exists THEN
    RAISE NOTICE '   ✅ notify_new_product_review: موجودة';
    
    -- فحص محتوى الـ function
    SELECT prosrc INTO v_test_result
    FROM pg_proc 
    WHERE proname = 'notify_new_product_review'
    LIMIT 1;
    
    IF v_test_result LIKE '%YOUR_CLOUDFLARE_WORKER_URL%' THEN
      RAISE NOTICE '   ⚠️  تحذير: URL مش متغير من القيمة الافتراضية!';
    ELSIF v_test_result LIKE '%notification-webhook.ah3181997-1e7.workers.dev%' THEN
      RAISE NOTICE '   ✅ URL: مضبوط (hardcoded في الـ function)';
    ELSIF v_test_result LIKE '%net.http_post%' THEN
      RAISE NOTICE '   ✅ يستخدم net.http_post';
    END IF;
  ELSE
    RAISE NOTICE '   ❌ notify_new_product_review: مفقودة!';
  END IF;
  
  -- Function لطلبات التقييم
  SELECT EXISTS(
    SELECT 1 FROM pg_proc WHERE proname = 'notify_new_review_request'
  ) INTO v_function_exists;
  
  IF v_function_exists THEN
    RAISE NOTICE '   ✅ notify_new_review_request: موجودة';
  ELSE
    RAISE NOTICE '   ❌ notify_new_review_request: مفقودة!';
  END IF;
  RAISE NOTICE '';
  
  -- ============================================================
  -- 3. فحص الـ Triggers
  -- ============================================================
  RAISE NOTICE '3️⃣ فحص الـ Triggers:';
  RAISE NOTICE '----------------------------------------';
  
  FOR v_trigger IN 
    SELECT 
      trigger_name,
      event_object_table,
      action_timing,
      event_manipulation
    FROM information_schema.triggers
    WHERE trigger_name LIKE '%notify%'
    ORDER BY trigger_name
  LOOP
    RAISE NOTICE '   ✅ %', v_trigger.trigger_name;
    RAISE NOTICE '      Table: %', v_trigger.event_object_table;
    RAISE NOTICE '      Event: % %', v_trigger.action_timing, v_trigger.event_manipulation;
  END LOOP;
  RAISE NOTICE '';
  
  -- ============================================================
  -- 4. فحص Database Webhooks
  -- ============================================================
  RAISE NOTICE '4️⃣ فحص Database Webhooks من Dashboard:';
  RAISE NOTICE '----------------------------------------';
  RAISE NOTICE '   ℹ️  لا يمكن فحصها من SQL';
  RAISE NOTICE '   👉 تحقق يدوياً من: Database → Webhooks';
  RAISE NOTICE '   المطلوب: حذفها إذا كنت تستخدم SQL Triggers';
  RAISE NOTICE '';
  
  -- ============================================================
  -- 5. فحص آخر التعليقات
  -- ============================================================
  RAISE NOTICE '5️⃣ آخر التعليقات المضافة:';
  RAISE NOTICE '----------------------------------------';
  
  FOR v_recent_review IN 
    SELECT 
      id,
      user_name,
      rating,
      CASE 
        WHEN comment IS NULL THEN '(بدون تعليق)'
        WHEN comment = '' THEN '(فارغ)'
        ELSE substring(comment, 1, 50)
      END as comment_preview,
      created_at
    FROM product_reviews
    WHERE created_at >= now() - interval '24 hours'
    ORDER BY created_at DESC
    LIMIT 5
  LOOP
    RAISE NOTICE '   • % - Rating: %', v_recent_review.user_name, v_recent_review.rating;
    RAISE NOTICE '     Comment: %', v_recent_review.comment_preview;
    RAISE NOTICE '     Time: %', v_recent_review.created_at;
    RAISE NOTICE '';
  END LOOP;
  
  -- ============================================================
  -- 6. اختبار يدوي للـ function
  -- ============================================================
  RAISE NOTICE '6️⃣ اختبار Function يدوياً:';
  RAISE NOTICE '----------------------------------------';
  
  IF v_pg_net THEN
    RAISE NOTICE '   💡 لاختبار الـ function يدوياً، نفذ:';
    RAISE NOTICE '';
    RAISE NOTICE '   INSERT INTO product_reviews (';
    RAISE NOTICE '     review_request_id, product_id, product_type,';
    RAISE NOTICE '     user_id, rating, comment';
    RAISE NOTICE '   ) VALUES (';
    RAISE NOTICE '     (SELECT id FROM review_requests LIMIT 1),';
    RAISE NOTICE '     ''test'', ''product'',';
    RAISE NOTICE '     auth.uid(), 5, ''تعليق تجريبي للاختبار''';
    RAISE NOTICE '   );';
    RAISE NOTICE '';
  ELSE
    RAISE NOTICE '   ⚠️  pg_net غير مفعل - لا يمكن الاختبار';
  END IF;
  
  -- ============================================================
  -- 7. ملخص نهائي
  -- ============================================================
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '📝 ملخص النتائج:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  
  IF NOT v_pg_net THEN
    RAISE NOTICE '❌ المشكلة الرئيسية: pg_net غير مفعل!';
    RAISE NOTICE '   الحل: CREATE EXTENSION IF NOT EXISTS pg_net;';
  ELSE
    RAISE NOTICE '✅ pg_net مفعل';
    RAISE NOTICE '';
    RAISE NOTICE '📋 الخطوات التالية:';
    RAISE NOTICE '1. تحقق من Database Webhooks في Dashboard';
    RAISE NOTICE '   - إذا موجودة → احذفها';
    RAISE NOTICE '2. تأكد من الـ Functions تحتوي URL صحيح';
    RAISE NOTICE '3. جرب إضافة تعليق جديد';
    RAISE NOTICE '4. راقب Logs في Supabase:';
    RAISE NOTICE '   Database → Logs → ابحث عن "Webhook sent"';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  
END $$;
