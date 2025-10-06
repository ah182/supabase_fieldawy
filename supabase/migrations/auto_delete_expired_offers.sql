-- Function لحذف العروض القديمة (أكثر من 7 أيام من تاريخ الإنشاء)
CREATE OR REPLACE FUNCTION delete_expired_offers()
RETURNS void AS $$
BEGIN
  DELETE FROM offers
  WHERE created_at < (NOW() - INTERVAL '7 days');
END;
$$ LANGUAGE plpgsql;

-- إنشاء extension إذا لم يكن موجوداً
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule لتشغيل الوظيفة يومياً في منتصف الليل
SELECT cron.schedule(
  'delete-expired-offers',
  '0 0 * * *', -- كل يوم في منتصف الليل
  'SELECT delete_expired_offers();'
);

-- ملاحظة: إذا كان pg_cron غير متاح في Supabase، يمكن استخدام Supabase Edge Functions بدلاً من ذلك
-- أو استخدام trigger عند كل query:

-- بديل: إنشاء trigger لحذف العروض القديمة عند الاستعلام
CREATE OR REPLACE FUNCTION trigger_delete_expired_offers()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM offers
  WHERE expiration_date < (NOW() - INTERVAL '7 days');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- تطبيق trigger على عمليات SELECT (قد لا يكون فعالاً جداً)
-- الحل الأفضل هو استخدام Supabase Database Webhooks أو Edge Functions
