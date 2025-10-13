-- ============================================================================
-- التأكد من أن الإشعارات تُرسل فقط عند INSERT
-- ============================================================================
-- منع إرسال إشعارات عند UPDATE أو DELETE
-- ============================================================================

-- 1. التحقق من الـ triggers الموجودة
DO $$
DECLARE
  v_trigger record;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '📋 Triggers الموجودة للإشعارات:';
  RAISE NOTICE '';
  
  FOR v_trigger IN 
    SELECT 
      trigger_name,
      event_manipulation,
      event_object_table
    FROM information_schema.triggers
    WHERE trigger_name IN (
      'trigger_notify_new_review_request',
      'trigger_notify_new_product_review'
    )
  LOOP
    RAISE NOTICE '   ✓ %', v_trigger.trigger_name;
    RAISE NOTICE '     Table: %', v_trigger.event_object_table;
    RAISE NOTICE '     Event: %', v_trigger.event_manipulation;
    RAISE NOTICE '';
  END LOOP;
END $$;

-- 2. حذف وإعادة إنشاء الـ Triggers بشكل صحيح
-- Trigger لطلبات التقييم (فقط INSERT)
DROP TRIGGER IF EXISTS trigger_notify_new_review_request ON review_requests;

CREATE TRIGGER trigger_notify_new_review_request
AFTER INSERT ON review_requests  -- ✅ فقط INSERT
FOR EACH ROW
EXECUTE FUNCTION notify_new_review_request();

-- Trigger للتعليقات (فقط INSERT + شرط وجود comment)
DROP TRIGGER IF EXISTS trigger_notify_new_product_review ON product_reviews;

CREATE TRIGGER trigger_notify_new_product_review
AFTER INSERT ON product_reviews  -- ✅ فقط INSERT
FOR EACH ROW
WHEN (NEW.comment IS NOT NULL AND NEW.comment <> '')  -- ✅ فقط مع تعليق
EXECUTE FUNCTION notify_new_product_review();

-- 3. التأكد من عدم وجود triggers على DELETE أو UPDATE
DO $$
DECLARE
  v_unwanted_trigger record;
  v_found boolean := false;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🔍 البحث عن triggers غير مرغوبة...';
  RAISE NOTICE '';
  
  FOR v_unwanted_trigger IN
    SELECT 
      trigger_name,
      event_manipulation,
      event_object_table
    FROM information_schema.triggers
    WHERE event_object_table IN ('review_requests', 'product_reviews')
      AND event_manipulation IN ('UPDATE', 'DELETE')
      AND trigger_name LIKE '%notify%'
  LOOP
    v_found := true;
    RAISE WARNING '⚠️  Found unwanted trigger: %', v_unwanted_trigger.trigger_name;
    RAISE WARNING '   Table: %, Event: %', 
      v_unwanted_trigger.event_object_table,
      v_unwanted_trigger.event_manipulation;
  END LOOP;
  
  IF NOT v_found THEN
    RAISE NOTICE '✅ لا توجد triggers غير مرغوبة';
  END IF;
  
  RAISE NOTICE '';
END $$;

-- 4. رسالة تأكيد نهائية
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '✅ تم تكوين الإشعارات بشكل صحيح!';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '';
  RAISE NOTICE '📤 الإشعارات سترسل فقط عند:';
  RAISE NOTICE '   1. إضافة طلب تقييم جديد (INSERT على review_requests)';
  RAISE NOTICE '   2. إضافة تعليق جديد (INSERT على product_reviews مع comment)';
  RAISE NOTICE '';
  RAISE NOTICE '🚫 لن ترسل إشعارات عند:';
  RAISE NOTICE '   - تحديث (UPDATE)';
  RAISE NOTICE '   - حذف (DELETE)';
  RAISE NOTICE '   - إضافة تقييم بدون تعليق';
  RAISE NOTICE '';
  RAISE NOTICE '🎯 الخطوة التالية:';
  RAISE NOTICE '   - أعد نشر Cloudflare Worker المحدث';
  RAISE NOTICE '   - اختبر بإضافة طلب تقييم';
  RAISE NOTICE '   - اختبر بإضافة تعليق';
  RAISE NOTICE '';
END $$;
