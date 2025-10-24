-- الخطوة 1: إنشاء جدول لتتبع استخدام واجهة برمجة التطبيقات (API)
CREATE TABLE IF NOT EXISTS public.api_usage (
  id SERIAL PRIMARY KEY,
  service_name TEXT NOT NULL UNIQUE,
  request_count BIGINT NOT NULL DEFAULT 0,
  last_reset_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- إضافة عداد لـ MapTiler إذا لم يكن موجودًا
INSERT INTO public.api_usage (service_name)
VALUES ('maptiler')
ON CONFLICT (service_name) DO NOTHING;

-- تفعيل الوصول للجدول من خلال API
GRANT SELECT, UPDATE ON TABLE public.api_usage TO anon, authenticated;


-- الخطوة 2: إنشاء دالة لزيادة العداد (RPC Function)
CREATE OR REPLACE FUNCTION public.log_map_request()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- مهم جداً لأمان التحديث
AS $$
BEGIN
  UPDATE public.api_usage
  SET request_count = request_count + 1
  WHERE service_name = 'maptiler';
END;
$$;

-- صلاحيات استدعاء الدالة
GRANT EXECUTE ON FUNCTION public.log_map_request() TO anon, authenticated;


-- الخطوة 3: إنشاء دالة لإعادة تعيين العداد (يمكن استدعاؤها شهرياً عبر Cron Job)
CREATE OR REPLACE FUNCTION public.reset_map_usage()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.api_usage
  SET request_count = 0,
      last_reset_at = NOW()
  WHERE service_name = 'maptiler';
END;
$$;

-- صلاحيات استدعاء الدالة (يمكن تقييدها للمشرفين فقط إذا لزم الأمر)
GRANT EXECUTE ON FUNCTION public.reset_map_usage() TO service_role; -- آمن أكثر
