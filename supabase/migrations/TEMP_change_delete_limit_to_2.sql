-- ============================================================================
-- تغيير مؤقت: حذف التعليق عند 2 dislikes بدلاً من 10
-- ============================================================================

-- 1. تحديث الـ function
DROP FUNCTION IF EXISTS public.auto_delete_unpopular_review() CASCADE;

CREATE OR REPLACE FUNCTION public.auto_delete_unpopular_review()
RETURNS TRIGGER AS $$
BEGIN
  -- تغيير الشرط من >= 10 إلى >= 2
  IF NEW.unhelpful_count >= 2 THEN
    -- حذف التقييم
    DELETE FROM public.product_reviews WHERE id = NEW.id;
    
    RAISE NOTICE 'تم حذف التقييم % تلقائياً بسبب وصول عدد "غير مفيد" إلى %', NEW.id, NEW.unhelpful_count;
    
    RETURN NULL; -- منع UPDATE لأن الصف تم حذفه
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. حذف وإعادة إنشاء الـ trigger بالشرط الجديد
DROP TRIGGER IF EXISTS trigger_auto_delete_unpopular_review ON public.product_reviews;

CREATE TRIGGER trigger_auto_delete_unpopular_review
AFTER UPDATE OF unhelpful_count ON public.product_reviews
FOR EACH ROW
WHEN (NEW.unhelpful_count >= 2)  -- تغيير من 10 إلى 2
EXECUTE FUNCTION public.auto_delete_unpopular_review();

-- 3. رسالة تأكيد
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ تم تغيير الحد إلى 2 dislikes مؤقتاً';
  RAISE NOTICE '🧪 الآن يمكنك الاختبار بـ 2 dislikes فقط';
  RAISE NOTICE '⚠️ لا تنسى إرجاعه لـ 10 بعد الاختبار!';
  RAISE NOTICE '';
END $$;
