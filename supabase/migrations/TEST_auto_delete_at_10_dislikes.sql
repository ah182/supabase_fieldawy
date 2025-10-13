-- ============================================================================
-- اختبار حذف التعليق تلقائياً عند 10 dislikes
-- ============================================================================

-- 1. التحقق من وجود الـ trigger
DO $$
DECLARE
  v_trigger_exists boolean;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'trigger_auto_delete_unpopular_review'
  ) INTO v_trigger_exists;
  
  IF v_trigger_exists THEN
    RAISE NOTICE '✅ الـ trigger موجود: trigger_auto_delete_unpopular_review';
  ELSE
    RAISE NOTICE '❌ الـ trigger غير موجود!';
  END IF;
END $$;

-- 2. التأكد من الـ trigger function
DO $$
DECLARE
  v_function_exists boolean;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM pg_proc 
    WHERE proname = 'auto_delete_unpopular_review'
  ) INTO v_function_exists;
  
  IF v_function_exists THEN
    RAISE NOTICE '✅ الـ function موجودة: auto_delete_unpopular_review';
  ELSE
    RAISE NOTICE '❌ الـ function غير موجودة!';
  END IF;
END $$;

-- 3. عرض تفاصيل الـ trigger
DO $$
DECLARE
  v_trigger_info record;
BEGIN
  SELECT 
    tgname as trigger_name,
    tgtype,
    tgenabled
  INTO v_trigger_info
  FROM pg_trigger 
  WHERE tgname = 'trigger_auto_delete_unpopular_review';
  
  IF v_trigger_info IS NOT NULL THEN
    RAISE NOTICE '';
    RAISE NOTICE '📋 تفاصيل الـ trigger:';
    RAISE NOTICE '   اسم: %', v_trigger_info.trigger_name;
    RAISE NOTICE '   مفعل: %', 
      CASE v_trigger_info.tgenabled 
        WHEN 'O' THEN 'نعم' 
        ELSE 'لا' 
      END;
  END IF;
END $$;

-- 4. إنشاء test case (اختبار حقيقي)
DO $$
DECLARE
  v_test_review_id uuid;
  v_test_user_id uuid;
  v_initial_count int;
  v_review_exists boolean;
BEGIN
  -- أخذ أول review موجود
  SELECT id INTO v_test_review_id 
  FROM public.product_reviews 
  WHERE unhelpful_count < 10
  LIMIT 1;
  
  IF v_test_review_id IS NULL THEN
    RAISE NOTICE '⚠️ لا توجد تقييمات للاختبار';
    RETURN;
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '🧪 اختبار الحذف التلقائي:';
  RAISE NOTICE '   Review ID: %', v_test_review_id;
  
  -- قراءة العدد الحالي
  SELECT unhelpful_count INTO v_initial_count
  FROM public.product_reviews
  WHERE id = v_test_review_id;
  
  RAISE NOTICE '   العدد الحالي: %', v_initial_count;
  
  -- محاكاة وصول unhelpful_count إلى 10
  UPDATE public.product_reviews
  SET unhelpful_count = 10
  WHERE id = v_test_review_id;
  
  RAISE NOTICE '   تم تحديث العدد إلى 10...';
  
  -- التحقق من حذف الـ review
  SELECT EXISTS(
    SELECT 1 FROM public.product_reviews WHERE id = v_test_review_id
  ) INTO v_review_exists;
  
  IF v_review_exists THEN
    RAISE NOTICE '❌ التعليق لم يُحذف! الـ trigger غير شغال';
    -- إرجاع القيمة الأصلية
    UPDATE public.product_reviews
    SET unhelpful_count = v_initial_count
    WHERE id = v_test_review_id;
  ELSE
    RAISE NOTICE '✅ التعليق تم حذفه تلقائياً! الـ trigger شغال';
  END IF;
  
  RAISE NOTICE '';
END $$;

-- 5. نصائح للمستخدم
DO $$
BEGIN
  RAISE NOTICE '💡 للاختبار في التطبيق:';
  RAISE NOTICE '   1. اختر تعليق معين';
  RAISE NOTICE '   2. اضغط "غير مفيد" من 10 حسابات مختلفة';
  RAISE NOTICE '   3. عند الوصول لـ 10، التعليق سيُحذف تلقائياً';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️ ملاحظة: كل مستخدم يمكنه التصويت مرة واحدة فقط';
  RAISE NOTICE '   لذلك تحتاج 10 مستخدمين مختلفين للاختبار الكامل';
  RAISE NOTICE '';
END $$;
