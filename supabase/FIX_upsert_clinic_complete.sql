-- ============================================================================
-- إصلاح كامل: دالة upsert_clinic مع جلب رقم الواتساب تلقائياً
-- ============================================================================
-- يدعم الاستدعاء بـ 5 أو 6 parameters

-- الخطوة 1: حذف جميع النسخ القديمة
-- ============================================================================
DROP FUNCTION IF EXISTS public.upsert_clinic(uuid, text, double precision, double precision, text, text);
DROP FUNCTION IF EXISTS public.upsert_clinic(uuid, text, double precision, double precision, text);
DROP FUNCTION IF EXISTS public.upsert_clinic;

-- الخطوة 2: إنشاء الدالة الجديدة
-- ============================================================================
CREATE FUNCTION public.upsert_clinic(
  p_user_id uuid,
  p_clinic_name text,
  p_latitude double precision,
  p_longitude double precision,
  p_address text,
  p_phone_number text DEFAULT NULL  -- ✅ اختياري
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
    
    RAISE NOTICE '📞 جلب رقم الواتساب: % للمستخدم: %', v_phone_number, p_user_id;
  ELSE
    v_phone_number := p_phone_number;
    RAISE NOTICE '📞 استخدام الرقم المُمرر: %', v_phone_number;
  END IF;

  -- إنشاء أو تحديث العيادة
  INSERT INTO public.clinics (
    user_id, 
    clinic_name, 
    latitude, 
    longitude, 
    address, 
    phone_number, 
    location
  )
  VALUES (
    p_user_id, 
    p_clinic_name, 
    p_latitude, 
    p_longitude, 
    p_address, 
    v_phone_number,
    ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography
  )
  ON CONFLICT (user_id)
  DO UPDATE SET
    clinic_name = EXCLUDED.clinic_name,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    address = EXCLUDED.address,
    phone_number = EXCLUDED.phone_number,
    location = EXCLUDED.location,
    updated_at = NOW();
    
  RAISE NOTICE '✅ تم حفظ/تحديث العيادة: %', p_clinic_name;
END;
$$;

-- الخطوة 3: منح الصلاحيات
-- ============================================================================
GRANT EXECUTE ON FUNCTION public.upsert_clinic(uuid, text, double precision, double precision, text, text) TO anon, authenticated;

-- الخطوة 4: اختبار الدالة (اختياري)
-- ============================================================================
-- يمكنك تشغيل هذا للاختبار:
/*
SELECT upsert_clinic(
  p_user_id := 'your-user-id-here'::uuid,
  p_clinic_name := 'عيادة اختبار',
  p_latitude := 30.0444,
  p_longitude := 31.2357,
  p_address := 'القاهرة، مصر'
  -- p_phone_number محذوف → سيجلب whatsapp_number تلقائياً
);

-- تحقق من النتيجة
SELECT clinic_name, phone_number 
FROM clinics 
WHERE user_id = 'your-user-id-here';
*/

-- الخطوة 5: رسالة نجاح
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ تم إنشاء دالة upsert_clinic بنجاح';
    RAISE NOTICE '✅ يدعم 5 أو 6 parameters';
    RAISE NOTICE '✅ يجلب whatsapp_number تلقائياً إذا لم يُمرر phone_number';
    RAISE NOTICE '';
    RAISE NOTICE '📝 الاستخدام:';
    RAISE NOTICE '   - مع 5 params: يجلب whatsapp_number تلقائياً';
    RAISE NOTICE '   - مع 6 params: يستخدم phone_number المُمرر';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 جرّب الآن في التطبيق!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;
