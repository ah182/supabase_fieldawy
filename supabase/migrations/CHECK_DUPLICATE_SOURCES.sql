-- ============================================================================
-- فحص مصادر الإشعارات المتعددة
-- ============================================================================

DO $$
DECLARE
  v_trigger record;
  v_has_triggers boolean := false;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 فحص مصادر الإشعارات';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  
  -- 1. فحص SQL Triggers
  RAISE NOTICE '1️⃣ SQL Triggers:';
  RAISE NOTICE '----------------------------------------';
  
  FOR v_trigger IN 
    SELECT 
      trigger_name,
      event_object_table,
      event_manipulation
    FROM information_schema.triggers
    WHERE trigger_name LIKE '%notify%'
    ORDER BY trigger_name
  LOOP
    v_has_triggers := true;
    RAISE NOTICE '   ✅ %', v_trigger.trigger_name;
    RAISE NOTICE '      Table: %', v_trigger.event_object_table;
    RAISE NOTICE '      Event: %', v_trigger.event_manipulation;
    RAISE NOTICE '';
  END LOOP;
  
  IF NOT v_has_triggers THEN
    RAISE NOTICE '   ℹ️  لا توجد SQL Triggers';
  END IF;
  
  RAISE NOTICE '';
  
  -- 2. Database Webhooks (لا يمكن فحصها من SQL)
  RAISE NOTICE '2️⃣ Database Webhooks:';
  RAISE NOTICE '----------------------------------------';
  RAISE NOTICE '   ⚠️  يجب التحقق يدوياً من Dashboard:';
  RAISE NOTICE '   👉 Database → Webhooks';
  RAISE NOTICE '';
  RAISE NOTICE '   المفروض تشوف:';
  RAISE NOTICE '   - reviewrequests (إذا موجود)';
  RAISE NOTICE '   - productreviews (إذا موجود)';
  RAISE NOTICE '';
  
  -- 3. التشخيص
  RAISE NOTICE '========================================';
  RAISE NOTICE '💡 التشخيص:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  
  IF v_has_triggers THEN
    RAISE NOTICE '✅ SQL Triggers موجودة';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  إذا كان عندك Database Webhooks كمان:';
    RAISE NOTICE '   → هذا سبب التكرار!';
    RAISE NOTICE '';
    RAISE NOTICE '📝 الحل:';
    RAISE NOTICE '   1. اذهب لـ Database → Webhooks في Dashboard';
    RAISE NOTICE '   2. احذف reviewrequests webhook';
    RAISE NOTICE '   3. احذف productreviews webhook';
    RAISE NOTICE '   4. اترك SQL Triggers فقط';
  ELSE
    RAISE NOTICE '❌ لا توجد SQL Triggers';
    RAISE NOTICE '';
    RAISE NOTICE '💡 يجب الاعتماد على Database Webhooks من Dashboard';
    RAISE NOTICE '   أو إنشاء SQL Triggers';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  
END $$;
