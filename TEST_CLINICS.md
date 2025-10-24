# 🔍 استكشاف مشكلة عدم ظهور العيادات

## المشكلة:
الخريطة تعرض "لا توجد عيادات مسجلة بعد" رغم إضافة عيادة

---

## ✅ الخطوات للتحقق من المشكلة:

### 1. تحقق من قاعدة البيانات

افتح **Supabase Dashboard** واذهب لـ SQL Editor وشغّل:

```sql
-- تحقق من وجود جدول clinics
SELECT * FROM clinics;

-- تحقق من عدد العيادات
SELECT COUNT(*) as total_clinics FROM clinics;

-- تحقق من RLS policies
SELECT * FROM pg_policies WHERE tablename = 'clinics';
```

---

### 2. إذا كان الجدول فارغاً أو غير موجود

شغّل هذا SQL في Supabase:

```sql
-- ================================================
-- Create Clinics Table for Doctor Location Tracking
-- ================================================

-- Create clinics table
CREATE TABLE IF NOT EXISTS public.clinics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    clinic_name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address TEXT,
    phone_number TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_clinics_user_id ON public.clinics(user_id);
CREATE INDEX IF NOT EXISTS idx_clinics_location ON public.clinics(latitude, longitude);

-- Enable Row Level Security
ALTER TABLE public.clinics ENABLE ROW LEVEL SECURITY;

-- ================================================
-- RLS Policies for Clinics
-- ================================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "Anyone can view clinics" ON public.clinics;
DROP POLICY IF EXISTS "Doctors can insert their own clinic" ON public.clinics;
DROP POLICY IF EXISTS "Doctors can update their own clinic" ON public.clinics;
DROP POLICY IF EXISTS "Doctors can delete their own clinic" ON public.clinics;
DROP POLICY IF EXISTS "Admins can manage all clinics" ON public.clinics;

-- Allow everyone to view all clinics (for map display)
CREATE POLICY "Anyone can view clinics"
    ON public.clinics
    FOR SELECT
    USING (true);

-- Allow doctors to insert their own clinic
CREATE POLICY "Doctors can insert their own clinic"
    ON public.clinics
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'doctor'
        )
    );

-- Allow doctors to update their own clinic
CREATE POLICY "Doctors can update their own clinic"
    ON public.clinics
    FOR UPDATE
    USING (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'doctor'
        )
    )
    WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'doctor'
        )
    );

-- Allow doctors to delete their own clinic
CREATE POLICY "Doctors can delete their own clinic"
    ON public.clinics
    FOR DELETE
    USING (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'doctor'
        )
    );

-- Allow admins to manage all clinics
CREATE POLICY "Admins can manage all clinics"
    ON public.clinics
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- ================================================
-- Trigger to update updated_at timestamp
-- ================================================

CREATE OR REPLACE FUNCTION update_clinics_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_clinics_updated_at ON public.clinics;

CREATE TRIGGER set_clinics_updated_at
    BEFORE UPDATE ON public.clinics
    FOR EACH ROW
    EXECUTE FUNCTION update_clinics_updated_at();

-- ================================================
-- Comments
-- ================================================

COMMENT ON TABLE public.clinics IS 'Stores clinic locations for doctors';
COMMENT ON COLUMN public.clinics.user_id IS 'Reference to the doctor user';
COMMENT ON COLUMN public.clinics.clinic_name IS 'Name of the clinic (usually doctor name)';
COMMENT ON COLUMN public.clinics.latitude IS 'Clinic latitude coordinate';
COMMENT ON COLUMN public.clinics.longitude IS 'Clinic longitude coordinate';
COMMENT ON COLUMN public.clinics.address IS 'Human-readable address from geocoding';
COMMENT ON COLUMN public.clinics.phone_number IS 'Clinic contact phone number';
```

---

### 3. إضافة عيادة تجريبية للاختبار

بعد إنشاء الجدول، أضف عيادة تجريبية:

```sql
-- استبدل 'YOUR_USER_ID' بـ user_id الخاص بك
-- يمكنك الحصول عليه من جدول users

INSERT INTO public.clinics (
    user_id,
    clinic_name,
    latitude,
    longitude,
    address,
    phone_number
) VALUES (
    'YOUR_USER_ID',  -- استبدل هذا
    'عيادة د. أحمد التجريبية',
    30.0444,  -- القاهرة
    31.2357,
    'القاهرة، مصر',
    '01234567890'
);

-- تحقق من الإضافة
SELECT * FROM clinics;
```

---

### 4. التحقق من Flutter

في التطبيق، افتح:
1. سجل دخول كطبيب
2. اذهب للإعدادات
3. اضغط "تحديث موقع العيادة"
4. امنح إذن الموقع
5. يجب أن تُضاف العيادة تلقائياً

---

### 5. إذا كانت المشكلة في الكود

تحقق من logs التطبيق:

```bash
flutter run
```

ابحث عن أي أخطاء تتعلق بـ:
- `clinics`
- `allClinicsProvider`
- `Error fetching clinics`

---

## 🔧 حل سريع: إعادة تعيين الجدول

إذا لم ينفع شيء:

```sql
-- احذف الجدول القديم
DROP TABLE IF EXISTS public.clinics CASCADE;

-- ثم شغّل كل الـ SQL من الخطوة 2 مرة أخرى
```

---

## 📞 معلومات Debug مهمة

لمعرفة سبب المشكلة بالضبط، شغّل:

```sql
-- 1. تحقق من الجدول
\d+ clinics

-- 2. تحقق من RLS
SELECT * FROM pg_policies WHERE tablename = 'clinics';

-- 3. عدد العيادات
SELECT COUNT(*) FROM clinics;

-- 4. عينة من البيانات
SELECT id, clinic_name, latitude, longitude FROM clinics LIMIT 5;

-- 5. تحقق من أن الـ SELECT policy تسمح للجميع
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'clinics' AND cmd = 'SELECT';
```

---

## ✅ النتيجة المتوقعة

بعد تشغيل SQL الصحيح:
- ✅ جدول `clinics` موجود
- ✅ RLS policies مُفعّلة
- ✅ Policy "Anyone can view clinics" موجودة
- ✅ البيانات موجودة في الجدول
- ✅ الخريطة تعرض العيادات بنجاح

---

**ارسل لي نتيجة هذا الـ SQL حتى أساعدك أكثر:**

```sql
SELECT COUNT(*) as total FROM clinics;
```
