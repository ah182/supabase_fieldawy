-- الخطوة 1: تفعيل إضافة PostGIS (إذا لم تكن مفعلة)
-- PostGIS ضروري للتعامل مع البيانات الجغرافية بكفاءة
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;


-- الخطوة 2: إضافة حقل من نوع geography لجدول العيادات
-- هذا الحقل سيخزن الإحداثيات بصيغة محسّنة للاستعلامات الجغرافية
ALTER TABLE public.clinics
ADD COLUMN IF NOT EXISTS location geography(Point, 4326);


-- الخطوة 3: تحديث الحقل الجديد بالبيانات من خطوط الطول والعرض الحالية
-- هذه العملية تملأ الحقل الجديد بالبيانات الصحيحة
UPDATE public.clinics
SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
WHERE location IS NULL; -- فقط للحقول التي لم يتم تحديثها بعد


-- الخطوة 4: إنشاء فهرس (Index) جغرافي
-- هذا الفهرس هو سر الأداء العالي. بدونه، ستكون الاستعلامات بطيئة جداً
CREATE INDEX IF NOT EXISTS clinics_location_idx
ON public.clinics
USING GIST (location);
