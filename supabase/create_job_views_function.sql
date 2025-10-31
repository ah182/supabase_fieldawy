-- ===================================================================
-- إنشاء دالة زيادة مشاهدات الوظائف
-- ===================================================================

-- دالة زيادة مشاهدات الوظائف
CREATE OR REPLACE FUNCTION increment_job_views(p_job_id TEXT)
RETURNS void AS $$
BEGIN
  UPDATE job_offers 
  SET views_count = COALESCE(views_count, 0) + 1,
      updated_at = NOW()
  WHERE id = p_job_id;
END;
$$ LANGUAGE plpgsql;

-- التأكد من إنجاز الإعداد
SELECT 'Job views increment function created successfully!' as status;

-- اختبار الدالة (اختياري)
-- SELECT increment_job_views('test-job-id');