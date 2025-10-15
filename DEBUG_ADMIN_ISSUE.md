# 🔍 تشخيص مشكلة Admin Update

## 📊 الوضع الحالي

```
✅ Can read user: true       ← القراءة تعمل
❌ Update failed             ← التحديث لا يعمل
```

**التشخيص:** الـ policy للـ SELECT تعمل، لكن الـ policy للـ UPDATE لا تعمل.

---

## 🔬 خطوات التشخيص

### **الخطوة 1: تحقق من auth.uid()**

في Supabase SQL Editor، شغل:

```sql
SELECT 
    auth.uid() as my_id,
    auth.email() as my_email;
```

احفظ الـ **my_id** اللي طلع.

---

### **الخطوة 2: تحقق من role في الجدول**

```sql
SELECT 
    id, 
    email, 
    role 
FROM users 
WHERE id = auth.uid();
```

**يجب أن ترى:**
- الـ ID نفسه من الخطوة 1
- role = 'admin' ✅

**إذا لم تر role = 'admin':**
```sql
UPDATE users 
SET role = 'admin' 
WHERE id = auth.uid();
```

---

### **الخطوة 3: شوف الـ policies الموجودة**

```sql
SELECT 
    policyname,
    cmd,
    qual as using_clause,
    with_check
FROM pg_policies
WHERE tablename = 'users' 
AND cmd = 'UPDATE';
```

**يجب أن ترى policy للـ admin في UPDATE.**

---

### **الخطوة 4: اختبر الـ policy مباشرة**

```sql
-- اختبر الـ subquery اللي في الـ policy
SELECT 
    (SELECT role FROM users WHERE id = auth.uid()) as my_role;
```

**يجب أن يطلع:** `my_role = 'admin'`

---

## ✅ الحل حسب المشكلة

### **السيناريو 1: role مش admin**

```sql
UPDATE users 
SET role = 'admin' 
WHERE id = auth.uid();

-- أو بالبريد:
UPDATE users 
SET role = 'admin' 
WHERE email = 'your_email@example.com';
```

---

### **السيناريو 2: الـ policy مش موجودة أو خطأ**

```sql
-- احذف وأعد إنشاء
DROP POLICY IF EXISTS "admin_update_all" ON users;

CREATE POLICY "admin_update_all"
ON users FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
);
```

---

### **السيناريو 3: WITH CHECK بتعطل التحديث**

```sql
-- استخدم policy بدون WITH CHECK معقدة
DROP POLICY IF EXISTS "admin_update_all" ON users;

CREATE POLICY "admin_update_all"
ON users FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
)
WITH CHECK (true);  -- ⚠️ أي تحديث مسموح
```

---

### **السيناريو 4: مفيش فايدة - عطل RLS**

إذا جربت كل شيء ولم ينجح:

```sql
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
```

---

## 🎯 الحل الموصى به (شغله كامل)

في Supabase SQL Editor:

```sql
-- 1. احذف policies القديمة
DROP POLICY IF EXISTS "admin_update_all" ON users;
DROP POLICY IF EXISTS "update_own" ON users;

-- 2. عيّن نفسك admin
UPDATE users 
SET role = 'admin' 
WHERE id = auth.uid();

-- تحقق:
SELECT id, email, role FROM users WHERE id = auth.uid();

-- 3. أنشئ policy بسيطة
CREATE POLICY "update_own"
ON users FOR UPDATE TO authenticated
USING (auth.uid() = id);

CREATE POLICY "admin_update_all"
ON users FOR UPDATE TO authenticated
USING (
  (SELECT role FROM users WHERE id = auth.uid()) = 'admin'
);

-- 4. اختبر
SELECT policyname FROM pg_policies WHERE tablename = 'users' AND cmd = 'UPDATE';
```

---

## 📞 نقاط الفحص السريع

✅ هل auth.uid() يطلع قيمة؟
✅ هل الـ id في users يطابق auth.uid()؟
✅ هل role = 'admin' في الجدول؟
✅ هل الـ policy موجودة للـ UPDATE؟
✅ هل الـ subquery في الـ policy يطلع 'admin'؟

**إذا كل الإجابات نعم ولم ينجح → عطل RLS مؤقتاً.**

---

## 🚨 الحل الأخير (مضمون 100%)

```sql
-- عطل RLS
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- اختبر Admin Dashboard
-- يجب أن يشتغل فوراً!
```

للإنتاج لاحقاً، استخدم Service Role Key بدلاً من RLS للـ admin operations.

---

**شغل الخطوات أعلاه واحدة واحدة وأخبرني بالنتائج!** 🔍
