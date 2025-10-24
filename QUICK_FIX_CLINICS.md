# 🚀 حل سريع لمشكلة عدم ظهور العيادات

## المشكلة
الخريطة تعرض "لا توجد عيادات مسجلة بعد" رغم إضافة عيادة

---

## ✅ الحل السريع (5 دقائق)

### الخطوة 1️⃣: افتح Supabase Dashboard

اذهب إلى: https://supabase.com/dashboard/project/YOUR_PROJECT

### الخطوة 2️⃣: افتح SQL Editor

من القائمة الجانبية → **SQL Editor** → **New query**

### الخطوة 3️⃣: انسخ والصق هذا الـ SQL كامل

```sql
-- ================================================
-- إنشاء جدول العيادات
-- ================================================

-- حذف الجدول القديم إذا كان موجوداً (للتأكد من بداية نظيفة)
DROP TABLE IF EXISTS public.clinics CASCADE;

-- إنشاء الجدول
CREATE TABLE public.clinics (
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

-- Indexes للأداء
CREATE INDEX idx_clinics_user_id ON public.clinics(user_id);
CREATE INDEX idx_clinics_location ON public.clinics(latitude, longitude);

-- تفعيل RLS
ALTER TABLE public.clinics ENABLE ROW LEVEL SECURITY;

-- ================================================
-- RLS Policies - مهمة جداً!
-- ================================================

-- السماح للجميع بمشاهدة العيادات (Policy الأهم!)
CREATE POLICY "Anyone can view clinics"
    ON public.clinics
    FOR SELECT
    USING (true);

-- السماح للأطباء بإضافة عياداتهم
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

-- السماح للأطباء بتحديث عياداتهم
CREATE POLICY "Doctors can update their own clinic"
    ON public.clinics
    FOR UPDATE
    USING (auth.uid() = user_id);

-- السماح للأطباء بحذف عياداتهم
CREATE POLICY "Doctors can delete their own clinic"
    ON public.clinics
    FOR DELETE
    USING (auth.uid() = user_id);

-- السماح للأدمن بإدارة كل العيادات
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
-- Trigger للتحديث التلقائي
-- ================================================

CREATE OR REPLACE FUNCTION update_clinics_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_clinics_updated_at
    BEFORE UPDATE ON public.clinics
    FOR EACH ROW
    EXECUTE FUNCTION update_clinics_updated_at();

-- ================================================
-- إضافة عيادة تجريبية
-- ================================================

-- أولاً: احصل على user_id طبيب
-- شغّل هذا أولاً لتحصل على الـ ID:
-- SELECT id, display_name, role FROM public.users WHERE role = 'doctor' LIMIT 1;

-- ثم استبدل 'DOCTOR_USER_ID' بالـ ID الفعلي واشغّل هذا:
/*
INSERT INTO public.clinics (
    user_id,
    clinic_name,
    latitude,
    longitude,
    address,
    phone_number
) VALUES (
    'DOCTOR_USER_ID',  -- استبدل هذا بـ ID الطبيب
    'عيادة تجريبية',
    30.0444,  -- القاهرة
    31.2357,
    'القاهرة، مصر',
    '01234567890'
);
*/

-- ================================================
-- تحقق من النتيجة
-- ================================================

SELECT 
    c.id,
    c.clinic_name,
    c.latitude,
    c.longitude,
    u.display_name as doctor_name
FROM public.clinics c
LEFT JOIN public.users u ON c.user_id = u.id;

-- إذا ظهرت نتائج → نجح! ✅
-- إذا لم تظهر → تابع للخطوة التالية
```

### الخطوة 4️⃣: اضغط **Run** أو **Execute**

انتظر حتى ترى: **Success. No rows returned**

### الخطوة 5️⃣: احصل على user_id طبيب

شغّل هذا SQL:

```sql
SELECT id, display_name, role, email 
FROM public.users 
WHERE role = 'doctor' 
LIMIT 1;
```

انسخ الـ **id** (مثل: `a1b2c3d4-...`)

### الخطوة 6️⃣: أضف عيادة تجريبية

استبدل `DOCTOR_USER_ID_HERE` بالـ ID اللي نسخته:

```sql
INSERT INTO public.clinics (
    user_id,
    clinic_name,
    latitude,
    longitude,
    address,
    phone_number
) VALUES (
    'DOCTOR_USER_ID_HERE',  -- <-- ضع الـ ID هنا
    'عيادة د. أحمد البيطرية',
    30.0444,
    31.2357,
    'القاهرة، مصر',
    '01234567890'
);
```

### الخطوة 7️⃣: تحقق من النتيجة

```sql
SELECT * FROM public.clinics;
```

يجب أن ترى عيادة واحدة على الأقل ✅

---

## 🔄 الآن في التطبيق

1. **أعد تشغيل التطبيق**:
   ```bash
   flutter run
   ```

2. **افتح خريطة العيادات**:
   - من الإعدادات → "خريطة العيادات"

3. **يجب أن ترى**:
   - ✅ الخريطة تظهر
   - ✅ Marker أحمر على موقع العيادة
   - ✅ يمكنك الضغط عليه لرؤية التفاصيل

---

## 🐛 إذا لم تظهر بعد

### تحقق من Console logs:

ابحث عن هذه الرسائل:

```
🔍 Fetching all clinics...
📦 Response type: ...
📊 Response: ...
✅ Found X clinics
```

أو:

```
❌ Error fetching all clinics: ...
```

**أرسل لي الـ logs** وسأساعدك!

---

## ✅ Checklist النهائي

- [ ] جدول `clinics` موجود في Supabase
- [ ] RLS مُفعّل على الجدول
- [ ] Policy "Anyone can view clinics" موجودة
- [ ] يوجد على الأقل صف واحد في الجدول
- [ ] التطبيق يعمل بدون أخطاء
- [ ] الخريطة تعرض العيادات

---

## 📞 الدعم

إذا لم ينجح الحل:

1. شغّل هذا في Supabase:
   ```sql
   SELECT COUNT(*) as total FROM public.clinics;
   SELECT * FROM pg_policies WHERE tablename = 'clinics';
   ```

2. أرسل لي النتيجة + أي أخطاء من console التطبيق

**الملفات:**
- `TEST_CLINICS.md` - دليل التشخيص الكامل
- `QUICK_FIX_CLINICS.md` - هذا الملف (حل سريع)
