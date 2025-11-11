-- ============================================================================
-- تحديث دالة upsert_clinic لجلب رقم الواتساب تلقائياً
-- ============================================================================
-- عند إنشاء أو تحديث العيادة، يتم جلب whatsapp_number من جدول users
-- ووضعه تلقائياً في phone_number للعيادة

-- حذف جميع النسخ القديمة من الدالة
DROP FUNCTION IF EXISTS public.upsert_clinic(uuid, text, double precision, double precision, text, text);
DROP FUNCTION IF EXISTS public.upsert_clinic(uuid, text, double precision, double precision, text);

-- إنشاء الدالة الجديدة (مع phone_number اختياري)
CREATE OR REPLACE FUNCTION public.upsert_clinic(
  p_user_id uuid,
  p_clinic_name text,
  p_latitude double precision,
  p_longitude double precision,
  p_address text,
  p_phone_number text DEFAULT NULL  -- Optional: سيتم استبداله برقم الواتساب إذا كان NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_phone_number text;
BEGIN
  -- جلب رقم الواتساب من جدول users إذا لم يتم تمرير phone_number
  IF p_phone_number IS NULL OR p_phone_number = '' THEN
    SELECT whatsapp_number INTO v_phone_number
    FROM public.users
    WHERE id = p_user_id;
    
    -- Debug log
    RAISE NOTICE '📞 جلب رقم الواتساب: % للمستخدم: %', v_phone_number, p_user_id;
  ELSE
    v_phone_number := p_phone_number;
    RAISE NOTICE '📞 استخدام الرقم المُمرر: %', v_phone_number;
  END IF;

  -- إنشاء أو تحديث العيادة
  INSERT INTO public.clinics (user_id, clinic_name, latitude, longitude, address, phone_number, location)
  VALUES (
    p_user_id, 
    p_clinic_name, 
    p_latitude, 
    p_longitude, 
    p_address, 
    v_phone_number,  -- استخدام رقم الواتساب
    ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography
  )
  ON CONFLICT (user_id)
  DO UPDATE SET
    clinic_name = EXCLUDED.clinic_name,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    address = EXCLUDED.address,
    phone_number = EXCLUDED.phone_number,  -- تحديث الرقم
    location = EXCLUDED.location,
    updated_at = NOW();
    
  RAISE NOTICE '✅ تم حفظ/تحديث العيادة بنجاح';
END;
$$;

-- منح الصلاحيات للدالة (كلا الإصدارين)
GRANT EXECUTE ON FUNCTION public.upsert_clinic(uuid, text, double precision, double precision, text, text) TO anon, authenticated;

-- ملاحظة: PostgreSQL سيتعامل تلقائياً مع استدعاء الدالة بدون phone_number
-- لأن DEFAULT NULL يجعله optional

-- رسالة نجاح
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ تم تحديث دالة upsert_clinic';
    RAISE NOTICE '✅ الآن يتم جلب رقم الواتساب تلقائياً';
    RAISE NOTICE '✅ phone_number = users.whatsapp_number';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 اختبر بإنشاء أو تحديث عيادة';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;
