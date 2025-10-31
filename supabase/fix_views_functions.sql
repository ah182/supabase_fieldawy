-- ===================================================================
-- إصلاح دوال زيادة المشاهدات للوظائف والمستلزمات البيطرية
-- ===================================================================

-- ===================================================================
-- 1. إنشاء/إصلاح دالة زيادة مشاهدات الوظائف
-- ===================================================================

CREATE OR REPLACE FUNCTION increment_job_views(p_job_id TEXT)
RETURNS void AS $$
BEGIN
  UPDATE job_offers 
  SET views_count = COALESCE(views_count, 0) + 1,
      updated_at = NOW()
  WHERE id = p_job_id::UUID;
  
  -- للتأكد من أن التحديث تم
  IF NOT FOUND THEN
    RAISE NOTICE 'Job with ID % not found', p_job_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ===================================================================
-- 2. إنشاء/إصلاح دالة زيادة مشاهدات المستلزمات البيطرية
-- ===================================================================

CREATE OR REPLACE FUNCTION increment_vet_supply_views(p_supply_id TEXT)
RETURNS void AS $$
BEGIN
  UPDATE vet_supplies 
  SET views_count = COALESCE(views_count, 0) + 1,
      updated_at = NOW()
  WHERE id = p_supply_id::UUID;
  
  -- للتأكد من أن التحديث تم
  IF NOT FOUND THEN
    RAISE NOTICE 'Vet supply with ID % not found', p_supply_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ===================================================================
-- 3. اختبار الدوال
-- ===================================================================

-- اختبار دالة الوظائف
DO $$
DECLARE
  test_job_id TEXT;
BEGIN
  -- الحصول على أول وظيفة للاختبار
  SELECT id::TEXT INTO test_job_id FROM job_offers LIMIT 1;
  
  IF test_job_id IS NOT NULL THEN
    RAISE NOTICE 'Testing increment_job_views with ID: %', test_job_id;
    PERFORM increment_job_views(test_job_id);
    RAISE NOTICE 'Job views function test completed';
  ELSE
    RAISE NOTICE 'No job offers found for testing';
  END IF;
END $$;

-- اختبار دالة المستلزمات
DO $$
DECLARE
  test_supply_id TEXT;
BEGIN
  -- الحصول على أول مستلزم للاختبار
  SELECT id::TEXT INTO test_supply_id FROM vet_supplies LIMIT 1;
  
  IF test_supply_id IS NOT NULL THEN
    RAISE NOTICE 'Testing increment_vet_supply_views with ID: %', test_supply_id;
    PERFORM increment_vet_supply_views(test_supply_id);
    RAISE NOTICE 'Vet supply views function test completed';
  ELSE
    RAISE NOTICE 'No vet supplies found for testing';
  END IF;
END $$;

-- ===================================================================
-- 4. التحقق من أن الأعمدة موجودة
-- ===================================================================

-- التحقق من عمود views_count في جدول job_offers
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'job_offers' AND column_name = 'views_count'
  ) THEN
    -- إضافة العمود إذا لم يكن موجوداً
    ALTER TABLE job_offers ADD COLUMN views_count INTEGER DEFAULT 0;
    RAISE NOTICE 'Added views_count column to job_offers table';
  ELSE
    RAISE NOTICE 'views_count column already exists in job_offers table';
  END IF;
END $$;

-- التحقق من عمود views_count في جدول vet_supplies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'vet_supplies' AND column_name = 'views_count'
  ) THEN
    -- إضافة العمود إذا لم يكن موجوداً
    ALTER TABLE vet_supplies ADD COLUMN views_count INTEGER DEFAULT 0;
    RAISE NOTICE 'Added views_count column to vet_supplies table';
  ELSE
    RAISE NOTICE 'views_count column already exists in vet_supplies table';
  END IF;
END $$;

-- ===================================================================
-- 5. تقرير الحالة النهائية
-- ===================================================================

SELECT 
  'Views functions setup completed successfully!' as status,
  'increment_job_views() and increment_vet_supply_views() are ready' as functions,
  'views_count columns verified in both tables' as columns,
  'You can now test the views increment from Flutter app' as next_step;

-- ===================================================================
-- اختبار سريع (اختياري)
-- ===================================================================

/*
-- لاختبار الدوال يدوياً:

-- للوظائف:
SELECT increment_job_views('your-job-id-here');

-- للمستلزمات:
SELECT increment_vet_supply_views('your-supply-id-here');

-- للتحقق من النتائج:
SELECT id, title, views_count FROM job_offers ORDER BY updated_at DESC LIMIT 5;
SELECT id, name, views_count FROM vet_supplies ORDER BY updated_at DESC LIMIT 5;
*/