# 🔧 تعليمات إصلاح التعديل والحذف في Admin Dashboard

## المشكلة
التعديل والحذف مش شغالين بسبب **RLS Policies** في Supabase.

---

## ✅ الحل (خطوتين)

### الخطوة 1️⃣: تطبيق الـ SQL Policies

1. افتح **Supabase Dashboard**
2. اذهب إلى **SQL Editor**
3. افتح الملف: `supabase/FIX_ADMIN_EDIT_DELETE_POLICIES.sql`
4. انسخ كل المحتوى والصقه في SQL Editor
5. اضغط **Run**

---

### الخطوة 2️⃣: تأكد من Admin User

شغّل هذا الـ Query في Supabase SQL Editor:

```sql
-- التحقق من admin user
SELECT 
    id,
    email,
    display_name,
    role,
    account_status
FROM users
WHERE email = 'admin@fieldawy.com';
```

**النتيجة المطلوبة:**
- ✅ `role` = `'admin'`
- ✅ `account_status` = `'approved'`

**إذا كانت النتيجة خاطئة، شغّل:**

```sql
UPDATE users 
SET role = 'admin', account_status = 'approved' 
WHERE email = 'admin@fieldawy.com';
```

---

## 🧪 اختبار الحل

بعد تطبيق الـ Policies:

1. سجّل خروج من Admin Dashboard
2. سجّل دخول مرة تانية بحساب الـ admin:
   - Email: `admin@fieldawy.com`
   - Password: `Admin@123456`
3. جرب التعديل أو الحذف في أي tab
4. هتظهر رسالة:
   - ✅ **"Updated successfully"** (أخضر) → الحذف/التعديل نجح
   - ❌ **"Update/Delete failed"** (أحمر) → في مشكلة
   - ❌ **"Error: ..."** (أحمر) → رسالة الخطأ التفصيلية

---

## 📋 الـ Policies المُضافة

### Tables اللي تم إضافة Policies ليها:

1. ✅ `vet_supplies` - UPDATE + DELETE
2. ✅ `offers` - UPDATE + DELETE
3. ✅ `distributor_surgical_tools` - UPDATE + DELETE
4. ✅ `distributor_ocr_products` - UPDATE + DELETE
5. ✅ `vet_books` - DELETE
6. ✅ `vet_courses` - DELETE
7. ✅ `job_offers` - DELETE

---

## 🔍 التحقق من الـ Policies

شغّل هذا Query للتأكد من تطبيق الـ Policies:

```sql
SELECT 
    tablename,
    policyname,
    cmd,
    permissive
FROM pg_policies
WHERE tablename IN (
    'vet_supplies',
    'offers',
    'distributor_surgical_tools',
    'distributor_ocr_products',
    'vet_books',
    'vet_courses',
    'job_offers'
)
AND policyname LIKE 'admin_%'
ORDER BY tablename, policyname;
```

**النتيجة المتوقعة:**
يجب أن تظهر عدة policies بأسماء تبدأ بـ `admin_update_` و `admin_delete_`.

---

## ⚠️ مشاكل محتملة وحلولها

### المشكلة 1: "Update failed" بعد تطبيق SQL
**الحل:**
```sql
-- تأكد من تفعيل RLS
ALTER TABLE vet_supplies ENABLE ROW LEVEL SECURITY;
ALTER TABLE offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE distributor_surgical_tools ENABLE ROW LEVEL SECURITY;
ALTER TABLE distributor_ocr_products ENABLE ROW LEVEL SECURITY;
```

---

### المشكلة 2: "Error: ... not found"
**السبب:** الـ ID مش صح
**الحل:** تأكد من الـ IDs في الجداول:

```sql
-- فحص IDs في vet_supplies
SELECT id, name FROM vet_supplies LIMIT 5;

-- فحص IDs في offers
SELECT id, product_id FROM offers LIMIT 5;
```

---

### المشكلة 3: Policy موجود بالفعل
**الحل:**
```sql
-- احذف الـ policy القديم
DROP POLICY IF EXISTS "admin_update_all_vet_supplies" ON vet_supplies;

-- أنشئ الـ policy الجديد
CREATE POLICY "admin_update_all_vet_supplies"
ON vet_supplies
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);
```

---

## 🎯 Error Messages الجديدة

الآن الـ UI يعرض رسائل واضحة:

| الرسالة | المعنى |
|---------|---------|
| ✅ **"Updated successfully"** | التعديل نجح |
| ✅ **"Deleted successfully"** | الحذف نجح |
| ❌ **"Update failed"** | التعديل فشل (RLS أو صلاحيات) |
| ❌ **"Delete failed"** | الحذف فشل |
| ⚠️ **"Please fill all fields"** | في حقول فاضية |
| ⚠️ **"Invalid price"** | السعر مش رقم صحيح |
| ❌ **"Error: [details]"** | خطأ تفصيلي من Supabase |

---

## 🔐 ملاحظات أمنية

✅ **آمن:** الـ Policies تتحقق من أن المستخدم:
1. مسجل دخول (authenticated)
2. عنده `role = 'admin'` في جدول users
3. الـ `auth.uid()` يطابق admin user

❌ **غير آمن:** لا تستخدم Service Role Key في الـ client!

---

## 📞 الدعم

إذا ما زالت المشكلة موجودة:

1. **افتح Console في المتصفح** (F12)
2. **جرب التعديل/الحذف**
3. **شوف الـ Errors في Console**
4. **ارسل الـ Error message** للمساعدة

---

## ✨ بعد الإصلاح

الأدمن هيقدر:
- ✏️ تعديل **Vet Supplies** (Name, Description, Price, Phone, Status)
- ✏️ تعديل **Offers** (Price, Package, Description, Expiration Date)
- ✏️ تعديل **Surgical Tools** (Description, Price)
- ✏️ تعديل **OCR Products** (Price, Expiration Date)
- 🗑️ حذف أي item من أي tab

---

تاريخ الإنشاء: 2025
النسخة: 1.0
