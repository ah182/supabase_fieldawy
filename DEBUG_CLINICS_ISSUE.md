# 🔍 تشخيص مشكلة عدم ظهور العيادات

## الوضع الحالي:
- ✅ جدول `clinics` موجود في Supabase
- ✅ توجد بيانات عيادات في الجدول
- ❌ الخريطة تعرض "لا توجد عيادات مسجلة"

---

## 🎯 الأسباب المحتملة:

### 1️⃣ مشكلة RLS Policies

**الأرجح:** Policy "Anyone can view clinics" غير موجودة أو خطأ

**الحل:** شغّل هذا في Supabase SQL Editor:

```sql
-- تحقق من الـ policies الموجودة
SELECT 
    policyname, 
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'clinics';
```

**إذا لم تظهر نتائج أو لم تجد policy للـ SELECT:**

```sql
-- إنشاء أو تحديث الـ policy
DROP POLICY IF EXISTS "Anyone can view clinics" ON public.clinics;

CREATE POLICY "Anyone can view clinics"
    ON public.clinics
    FOR SELECT
    USING (true);
```

---

### 2️⃣ RLS مُفعّل لكن لا يوجد policy

**تحقق:**

```sql
-- تحقق من RLS
SELECT 
    tablename, 
    rowsecurity 
FROM pg_tables 
WHERE tablename = 'clinics' AND schemaname = 'public';
```

يجب أن يكون `rowsecurity = true`

**إذا كان true وليس هناك policy للـ SELECT، لن تظهر أي بيانات!**

---

### 3️⃣ مشكلة في اتصال Supabase

**تحقق من الكود:**

شغّل التطبيق وراقب console:

```bash
flutter run
```

ابحث عن:

```
🔍 Fetching all clinics...
📦 Response type: List<dynamic>
📊 Response: [{...}]
✅ Found X clinics
```

أو:

```
❌ Error fetching all clinics: ...
```

---

### 4️⃣ مشكلة في الـ URL أو API Key

**تحقق من:**

`lib/core/supabase/supabase_init.dart`

تأكد من:
- ✅ `SUPABASE_URL` صحيح
- ✅ `SUPABASE_ANON_KEY` صحيح
- ✅ لا توجد أخطاء في الاتصال

---

## 🚀 الحل الشامل (جرّب هذا):

### في Supabase SQL Editor:

```sql
-- ============================================
-- حل شامل لمشكلة RLS
-- ============================================

-- 1. حذف كل الـ policies القديمة
DROP POLICY IF EXISTS "Anyone can view clinics" ON public.clinics;
DROP POLICY IF EXISTS "Doctors can insert their own clinic" ON public.clinics;
DROP POLICY IF EXISTS "Doctors can update their own clinic" ON public.clinics;
DROP POLICY IF EXISTS "Doctors can delete their own clinic" ON public.clinics;
DROP POLICY IF EXISTS "Admins can manage all clinics" ON public.clinics;

-- 2. تأكد من RLS مُفعّل
ALTER TABLE public.clinics ENABLE ROW LEVEL SECURITY;

-- 3. إنشاء Policy للمشاهدة (الأهم!)
CREATE POLICY "Anyone can view clinics"
    ON public.clinics
    FOR SELECT
    USING (true);  -- يسمح للجميع بالمشاهدة

-- 4. Policy للأطباء للإضافة
CREATE POLICY "Doctors can insert clinic"
    ON public.clinics
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
    );

-- 5. Policy للأطباء للتحديث
CREATE POLICY "Doctors can update clinic"
    ON public.clinics
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 6. Policy للأطباء للحذف
CREATE POLICY "Doctors can delete clinic"
    ON public.clinics
    FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- التحقق
-- ============================================

-- تحقق من الـ policies
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'clinics';

-- يجب أن ترى على الأقل:
-- "Anyone can view clinics" | SELECT

-- تحقق من البيانات (بدون RLS)
SELECT COUNT(*) FROM public.clinics;

-- إذا كان العدد > 0، البيانات موجودة ✅
```

---

## 🧪 اختبار RLS مباشرة

```sql
-- اختبار 1: هل البيانات موجودة؟
SELECT * FROM public.clinics;

-- اختبار 2: هل RLS يسمح بالمشاهدة؟
SET LOCAL ROLE authenticated;
SELECT * FROM public.clinics;
RESET ROLE;

-- إذا الاختبار 1 يعرض بيانات والاختبار 2 لا يعرض
-- → المشكلة في RLS policy!
```

---

## 📱 في التطبيق

بعد تطبيق الحل في Supabase:

1. **أغلق التطبيق تماماً**
2. **أعد تشغيله:**
   ```bash
   flutter run
   ```
3. **افتح خريطة العيادات**
4. **راقب console logs**

---

## ✅ المتوقع بعد الحل:

### في Supabase:
```sql
SELECT * FROM pg_policies WHERE tablename = 'clinics';
```
يجب أن ترى على الأقل policy واحد لـ SELECT

### في التطبيق:
```
🔍 Fetching all clinics...
📦 Response type: List<dynamic>
📊 Response: [...]
✅ Found 1 clinics
```

---

## 🆘 إذا لم يحل:

**أرسل لي:**

1. **من Supabase:**
   ```sql
   -- نسخ نتيجة هذا
   SELECT policyname, cmd, qual 
   FROM pg_policies 
   WHERE tablename = 'clinics';
   
   SELECT COUNT(*) FROM clinics;
   ```

2. **من Flutter console:**
   - نسخ الـ logs من `🔍 Fetching` حتى `✅ Found` أو `❌ Error`

3. **Screenshot من شاشة الخريطة**

وسأحدد المشكلة بالضبط! 🚀
