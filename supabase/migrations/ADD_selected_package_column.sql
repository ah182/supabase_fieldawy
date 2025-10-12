-- ============================================================================
-- إضافة عمود selected_package إلى جدول products
-- ============================================================================

-- التحقق من وجود العمود وإضافته إن لم يكن موجوداً
DO $$ 
BEGIN
  -- إضافة العمود إلى جدول products
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'products' 
      AND column_name = 'selected_package'
  ) THEN
    ALTER TABLE public.products 
    ADD COLUMN selected_package text;
    
    RAISE NOTICE '✅ تم إضافة عمود selected_package إلى جدول products';
  ELSE
    RAISE NOTICE '⚠️ عمود selected_package موجود بالفعل في جدول products';
  END IF;
  
  -- نسخ القيم من package إلى selected_package للسجلات الموجودة
  UPDATE public.products
  SET selected_package = package
  WHERE selected_package IS NULL AND package IS NOT NULL;
  
  RAISE NOTICE '✅ تم نسخ القيم من package إلى selected_package';
  
END $$;

-- ============================================================================
-- نهاية
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ اكتمل إضافة عمود selected_package';
  RAISE NOTICE '📦 الآن يمكنك استخدام selected_package في الاستعلامات';
END $$;
