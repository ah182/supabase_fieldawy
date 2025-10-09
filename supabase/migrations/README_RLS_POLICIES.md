# 🔐 Row Level Security (RLS) Policies

## نظرة عامة

تم تطبيق سياسات أمان على مستوى الصفوف (RLS) لحماية البيانات في الجداول التالية:

### 1. `surgical_tools` - كتالوج الأدوات الجراحية

#### السياسات:

| العملية | السياسة | الشرط |
|---------|---------|-------|
| **SELECT** ✅ | `surgical_tools_select_authenticated` | جميع المستخدمين المصادقين |
| **INSERT** ✍️ | `surgical_tools_insert_authenticated` | المستخدم المصادق (يجب أن يكون `created_by = auth.uid()`) |
| **UPDATE** 📝 | `surgical_tools_update_owner` | المستخدم الذي أضاف الأداة فقط |
| **DELETE** 🗑️ | `surgical_tools_delete_owner` | المستخدم الذي أضاف الأداة فقط |

#### الهدف:
- أي مستخدم يمكنه رؤية كتالوج الأدوات الجراحية
- فقط المستخدم الذي أضاف أداة معينة يمكنه تعديلها أو حذفها

---

### 2. `distributor_surgical_tools` - أدوات الموزعين

#### السياسات:

| العملية | السياسة | الشرط |
|---------|---------|-------|
| **SELECT** ✅ | `distributor_surgical_tools_select_authenticated` | جميع المستخدمين المصادقين |
| **INSERT** ✍️ | `distributor_surgical_tools_insert_owner` | الموزع فقط (يجب أن يكون `distributor_id = auth.uid()`) |
| **UPDATE** 📝 | `distributor_surgical_tools_update_owner` | الموزع صاحب الأداة فقط |
| **DELETE** 🗑️ | `distributor_surgical_tools_delete_owner` | الموزع صاحب الأداة فقط |

#### الهدف:
- أي مستخدم يمكنه رؤية أدوات جميع الموزعين
- كل موزع يمكنه فقط إضافة/تعديل/حذف أدواته الخاصة

---

### 3. `offers` - العروض

#### السياسات:

| العملية | السياسة | الشرط |
|---------|---------|-------|
| **SELECT** ✅ | `offers_select_authenticated` | جميع المستخدمين المصادقين |
| **INSERT** ✍️ | `offers_insert_owner` | المستخدم فقط (يجب أن يكون `user_id = auth.uid()`) |
| **UPDATE** 📝 | `offers_update_owner` | صاحب العرض فقط |
| **DELETE** 🗑️ | `offers_delete_owner` | صاحب العرض فقط |

#### الهدف:
- أي مستخدم يمكنه رؤية جميع العروض
- كل مستخدم يمكنه فقط إضافة/تعديل/حذف عروضه الخاصة

---

## 📊 بنية جدول offers

```sql
CREATE TABLE offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id text NOT NULL,                    -- معرف المنتج
  is_ocr boolean NOT NULL DEFAULT false,       -- OCR أم كتالوج
  user_id uuid NOT NULL,                       -- صاحب العرض
  price numeric(12,2) NOT NULL,                -- سعر العرض
  expiration_date timestamptz NOT NULL,        -- تاريخ الانتهاء
  description text,                             -- وصف العرض
  package text,                                 -- العبوة
  created_at timestamptz DEFAULT NOW(),
  updated_at timestamptz DEFAULT NOW()
);
```

---

## 🚀 كيفية التطبيق

### الطريقة 1: باستخدام Supabase CLI

```bash
cd D:\fieldawy_store
supabase db push
```

### الطريقة 2: عبر Supabase Dashboard

1. افتح [Supabase Dashboard](https://supabase.com/dashboard)
2. اذهب إلى مشروعك
3. اختر **SQL Editor** من القائمة الجانبية
4. انسخ محتوى ملف `rls_surgical_tools_and_offers.sql`
5. الصق في المحرر واضغط **Run**

---

## 🧪 اختبار السياسات

### اختبار القراءة (يجب أن ينجح):
```sql
SELECT * FROM surgical_tools;
SELECT * FROM distributor_surgical_tools;
SELECT * FROM offers;
```

### اختبار الكتابة (يجب أن ينجح فقط للبيانات الخاصة بك):
```sql
-- إضافة أداة جراحية
INSERT INTO surgical_tools (tool_name, company, created_by)
VALUES ('Test Tool', 'Test Company', auth.uid());

-- إضافة عرض
INSERT INTO offers (product_id, is_ocr, user_id, price, expiration_date)
VALUES ('test-product-id', false, auth.uid(), 100.00, NOW() + INTERVAL '7 days');
```

### اختبار الكتابة (يجب أن يفشل - محاولة إضافة بيانات لمستخدم آخر):
```sql
-- سيفشل لأن user_id لا يطابق auth.uid()
INSERT INTO offers (product_id, is_ocr, user_id, price, expiration_date)
VALUES ('test-product-id', false, 'different-user-id', 100.00, NOW() + INTERVAL '7 days');
```

---

## 🔍 فحص السياسات الحالية

```sql
-- عرض جميع السياسات على جدول معين
SELECT * FROM pg_policies WHERE tablename = 'surgical_tools';
SELECT * FROM pg_policies WHERE tablename = 'distributor_surgical_tools';
SELECT * FROM pg_policies WHERE tablename = 'offers';
```

---

## 🛠️ حذف السياسات (إذا احتجت إعادة التطبيق)

```sql
-- حذف جميع السياسات من surgical_tools
DROP POLICY IF EXISTS "surgical_tools_select_authenticated" ON surgical_tools;
DROP POLICY IF EXISTS "surgical_tools_insert_authenticated" ON surgical_tools;
DROP POLICY IF EXISTS "surgical_tools_update_owner" ON surgical_tools;
DROP POLICY IF EXISTS "surgical_tools_delete_owner" ON surgical_tools;

-- حذف جميع السياسات من distributor_surgical_tools
DROP POLICY IF EXISTS "distributor_surgical_tools_select_authenticated" ON distributor_surgical_tools;
DROP POLICY IF EXISTS "distributor_surgical_tools_insert_owner" ON distributor_surgical_tools;
DROP POLICY IF EXISTS "distributor_surgical_tools_update_owner" ON distributor_surgical_tools;
DROP POLICY IF EXISTS "distributor_surgical_tools_delete_owner" ON distributor_surgical_tools;

-- حذف جميع السياسات من offers
DROP POLICY IF EXISTS "offers_select_authenticated" ON offers;
DROP POLICY IF EXISTS "offers_insert_owner" ON offers;
DROP POLICY IF EXISTS "offers_update_owner" ON offers;
DROP POLICY IF EXISTS "offers_delete_owner" ON offers;
```

---

## ⚠️ ملاحظات مهمة

1. **RLS مفعّل افتراضياً**: بمجرد تطبيق هذه السياسات، لن يتمكن أي مستخدم من الوصول للبيانات إلا من خلال السياسات المحددة

2. **المستخدمون غير المصادقين**: لن يتمكنوا من الوصول لأي بيانات (جميع السياسات تتطلب `authenticated`)

3. **Service Role**: إذا كنت تستخدم Service Role Key في Backend، ستتجاوز جميع سياسات RLS

4. **التنظيف التلقائي**: دالة `cleanup_old_offers()` متوفرة لحذف العروض القديمة (أكثر من 7 أيام)
   ```sql
   SELECT cleanup_old_offers();
   ```

---

## 📞 الدعم

إذا واجهت أي مشكلة مع السياسات:

1. تحقق من أن المستخدم مصادق (authenticated)
2. تحقق من أن `auth.uid()` يطابق `user_id` أو `distributor_id` أو `created_by`
3. استخدم Supabase Logs للتحقق من الأخطاء

---

✅ **تم تطبيق جميع السياسات بنجاح!**
