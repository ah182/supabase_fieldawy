-- ============================================================================
-- حذف triggers التقييمات فقط (مش كل التريجرات!)
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🗑️ حذف triggers التقييمات فقط...';
  RAISE NOTICE '';
END $$;

-- 1. حذف triggers التقييمات
DROP TRIGGER IF EXISTS trigger_notify_new_review_request ON review_requests CASCADE;
DROP TRIGGER IF EXISTS trigger_notify_new_product_review ON product_reviews CASCADE;

-- 2. حذف functions التقييمات
DROP FUNCTION IF EXISTS notify_new_review_request() CASCADE;
DROP FUNCTION IF EXISTS notify_new_product_review() CASCADE;

-- 3. التحقق من النتيجة
DO $$
DECLARE
  v_remaining_triggers int;
  v_review_triggers int;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ تم حذف triggers التقييمات';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  
  -- عدد triggers التقييمات المتبقية
  SELECT COUNT(*) INTO v_review_triggers
  FROM information_schema.triggers
  WHERE event_object_table IN ('review_requests', 'product_reviews')
    AND trigger_name LIKE '%notify%';
  
  IF v_review_triggers = 0 THEN
    RAISE NOTICE '✅ triggers التقييمات: تم الحذف بنجاح';
  ELSE
    RAISE WARNING '⚠️  لا يزال هناك % trigger للتقييمات', v_review_triggers;
  END IF;
  
  -- عدد كل الـ triggers (للتأكد إن الباقي لسه موجود)
  SELECT COUNT(*) INTO v_remaining_triggers
  FROM information_schema.triggers
  WHERE trigger_name LIKE '%notify%';
  
  IF v_remaining_triggers > 0 THEN
    RAISE NOTICE '✅ الأنظمة الأخرى: % trigger لا تزال موجودة', v_remaining_triggers;
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '📋 الآن الإشعارات تعمل عبر:';
  RAISE NOTICE '   ✅ Database Webhooks فقط';
  RAISE NOTICE '   ❌ لا توجد SQL Triggers للتقييمات';
  RAISE NOTICE '';
  RAISE NOTICE '🧪 اختبر الآن:';
  RAISE NOTICE '   - أضف تعليق → يجب أن يظهر إشعار واحد';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  
END $$;
