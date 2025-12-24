-- ====================================
-- Add Clinic Code & Fix Relationships (COMPLETE)
-- Created: 2025-12-24
-- Description: Ensures Foreign Key exists, adds clinic_code, and rebuilds the view
-- ====================================

-- 1. التأكد من وجود قيد المفتاح الأجنبي (Relationship)
-- هذا ضروري لعملية الـ Join في Flutter
ALTER TABLE public.clinics 
DROP CONSTRAINT IF EXISTS clinics_user_id_fkey;

ALTER TABLE public.clinics 
ADD CONSTRAINT clinics_user_id_fkey 
FOREIGN KEY (user_id) 
REFERENCES public.users(id) 
ON DELETE CASCADE;

-- 2. إضافة عمود كود العيادة للجدول الأساسي
ALTER TABLE public.clinics ADD COLUMN IF NOT EXISTS clinic_code TEXT UNIQUE;

-- 3. توليد أكواد للبيانات القديمة
UPDATE public.clinics 
SET clinic_code = 'CL-' || upper(substring(id::text from 1 for 4))
WHERE clinic_code IS NULL;

-- 4. حذف الـ View لتجنب خطأ تعارض الأعمدة أو العلاقات
DROP VIEW IF EXISTS public.clinics_with_doctor_info;

-- 5. إعادة إنشاء الـ View (مع كود العيادة الجديد وأرقام الهاتف)
CREATE OR REPLACE VIEW public.clinics_with_doctor_info AS
SELECT 
    c.id AS clinic_id,
    c.clinic_name,
    c.latitude,
    c.longitude,
    c.address,
    COALESCE(c.phone_number, u.whatsapp_number) AS clinic_phone_number, -- استخدام واتساب الطبيب كبديل إذا كان هاتف العيادة فارغاً
    c.clinic_code,
    c.created_at,
    c.updated_at,
    u.id AS user_id,
    u.display_name AS doctor_name,
    u.whatsapp_number AS doctor_whatsapp_number,
    u.photo_url AS doctor_photo_url
FROM public.clinics c
JOIN public.users u ON c.user_id = u.id;

-- 6. تحديث دالة الحفظ المحدثة (upsert_clinic_v2)
CREATE OR REPLACE FUNCTION public.upsert_clinic_v2(
    p_user_id UUID,
    p_clinic_name TEXT,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_address TEXT DEFAULT NULL,
    p_phone_number TEXT DEFAULT NULL,
    p_clinic_code TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.clinics (
        user_id, clinic_name, latitude, longitude, address, phone_number, clinic_code
    )
    VALUES (
        p_user_id, p_clinic_name, p_latitude, p_longitude, p_address, p_phone_number, p_clinic_code
    )
    ON CONFLICT (user_id) DO UPDATE SET
        clinic_name = EXCLUDED.clinic_name,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        address = EXCLUDED.address,
        phone_number = EXCLUDED.phone_number,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. منح الصلاحيات اللازمة
GRANT SELECT ON public.clinics_with_doctor_info TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.upsert_clinic_v2 TO authenticated;

-- إضافة تعليق توضيحي للعمود
COMMENT ON COLUMN public.clinics.clinic_code IS 'Unique short code for the clinic (e.g. CL-A1B2)';
