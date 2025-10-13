-- ============================================================================
-- إرجاع الحد الأصلي: حذف التعليق عند 10 dislikes
-- ============================================================================

-- 1. تحديث الـ function
DROP FUNCTION IF EXISTS public.auto_delete_unpopular_review() CASCADE;

CREATE OR REPLACE FUNCTION public.auto_delete_unpopular_review()
RETURNS TRIGGER AS $$
BEGIN
  -- الشرط الأصلي >= 10
  IF NEW.unhelpful_count >= 10 THEN
    -- حذف التقييم
    DELETE FROM public.product_reviews WHERE id = NEW.id;
    
    RAISE NOTICE 'تم حذف التقييم % تلقائياً بسبب وصول عدد "غير مفيد" إلى %', NEW.id, NEW.unhelpful_count;
    
    RETURN NULL; -- منع UPDATE لأن الصف تم حذفه
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. حذف وإعادة إنشاء الـ trigger
DROP TRIGGER IF EXISTS trigger_auto_delete_unpopular_review ON public.product_reviews;

CREATE TRIGGER trigger_auto_delete_unpopular_review
AFTER UPDATE OF unhelpful_count ON public.product_reviews
FOR EACH ROW
WHEN (NEW.unhelpful_count >= 10)  -- الحد الأصلي 10
EXECUTE FUNCTION public.auto_delete_unpopular_review();

-- 3. رسالة تأكيد
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ تم إرجاع الحد إلى 10 dislikes';
  RAISE NOTICE '🎯 النظام عاد للوضع الطبيعي';
  RAISE NOTICE '';
END $$;
