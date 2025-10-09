# 🔒 دليل Row Level Security (RLS) Policies

## ✅ ما تم إضافته

تم إضافة RLS policies شاملة لـ:
1. ✅ جدول `user_tokens` (FCM Tokens)
2. ✅ جدول `notification_logs` (سجل الإشعارات)
3. ✅ Views: `distributor_products_expiring_soon` و `distributor_products_price_changes`
4. ✅ Functions: جميع الدوال المتعلقة بالإشعارات

---

## 📊 RLS Policies للجداول

### 1️⃣ جدول `user_tokens`

| Policy | الوصف | من يستطيع |
|--------|-------|-----------|
| **Users can view their own tokens** | رؤية tokens الخاصة به | المستخدم نفسه فقط |
| **Users can insert their own tokens** | إضافة tokens لنفسه | المستخدم نفسه فقط |
| **Users can update their own tokens** | تحديث tokens الخاصة به | المستخدم نفسه فقط |
| **Users can delete their own tokens** | حذف tokens الخاصة به | المستخدم نفسه فقط |
| **Admins can view all tokens** | رؤية جميع tokens | Admin فقط |

#### مثال:

```sql
-- مستخدم عادي (user_id = abc-123)
SELECT * FROM user_tokens;
-- النتيجة: يرى tokens الخاصة به فقط (abc-123)

-- Admin
SELECT * FROM user_tokens;
-- النتيجة: يرى جميع tokens لجميع المستخدمين
```

---

### 2️⃣ جدول `notification_logs`

| Policy | الوصف | من يستطيع |
|--------|-------|-----------|
| **Authenticated users can view notification logs** | رؤية سجل الإشعارات | جميع المستخدمين المصادقين |
| **System can insert notification logs** | إضافة سجلات جديدة | النظام (service_role) فقط |
| **Admins can update notification logs** | تحديث حالة الإشعارات | Admin فقط |
| **Admins can delete notification logs** | حذف سجلات قديمة | Admin فقط |

#### مثال:

```sql
-- مستخدم عادي
SELECT * FROM notification_logs;
-- ✅ يمكنه الرؤية (للشفافية)

-- مستخدم عادي يحاول الإضافة
INSERT INTO notification_logs (...) VALUES (...);
-- ❌ ممنوع! فقط النظام

-- Admin يحذف سجلات قديمة
DELETE FROM notification_logs WHERE sent_at < NOW() - INTERVAL '30 days';
-- ✅ مسموح
```

---

## 📊 RLS للـ Views

### Views ترث RLS من الجداول الأساسية

- `distributor_products_expiring_soon` ← ترث من `distributor_products` و `products`
- `distributor_products_price_changes` ← ترث من `distributor_products` و `products`
- `notification_stats` ← ترث من `notification_logs`

#### Permissions:

```sql
GRANT SELECT ON distributor_products_expiring_soon TO authenticated;
GRANT SELECT ON distributor_products_price_changes TO authenticated;
GRANT SELECT ON notification_stats TO authenticated;
```

جميع المستخدمين المصادقين يمكنهم قراءة هذه Views ✅

---

## 🔧 Functions Security

### SECURITY DEFINER vs SECURITY INVOKER

| Function | Security Mode | السبب |
|----------|--------------|-------|
| `get_expiring_products()` | **DEFINER** | تعمل بصلاحيات المالك، تتجاوز RLS |
| `get_price_changed_products()` | **DEFINER** | تعمل بصلاحيات المالك |
| `upsert_user_token()` | **DEFINER** | يسمح للمستخدم بحفظ token بدون تعقيدات RLS |
| `delete_user_token()` | **DEFINER** | يسمح بالحذف مع التحقق الداخلي |
| `log_notification()` | **DEFINER** | يسمح للنظام بإضافة سجلات |

#### ما معنى SECURITY DEFINER؟

```sql
-- Function بـ SECURITY DEFINER
CREATE FUNCTION get_expiring_products(...)
RETURNS TABLE (...)
LANGUAGE plpgsql
SECURITY DEFINER; -- ✅ تعمل بصلاحيات من أنشأ الدالة

-- يعني:
-- المستخدم العادي يستطيع استدعاء الدالة
-- لكن الدالة تعمل بصلاحيات "المالك" (owner)
-- فتتجاوز RLS وتجلب جميع البيانات
```

#### Permissions:

```sql
-- المستخدمون المصادقون يمكنهم استخدام هذه Functions
GRANT EXECUTE ON FUNCTION get_expiring_products(int) TO authenticated;
GRANT EXECUTE ON FUNCTION get_price_changed_products(int) TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_user_token(...) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_token(...) TO authenticated;

-- log_notification فقط للنظام
GRANT EXECUTE ON FUNCTION log_notification(...) TO service_role;
```

---

## 🧪 اختبار RLS

### Test 1: المستخدم يرى tokens الخاصة به فقط

```sql
-- سجل الدخول كمستخدم (user_id = abc-123)
SELECT * FROM user_tokens;

-- النتيجة المتوقعة:
-- token             | user_id
-- ------------------|---------
-- xyz-token-1       | abc-123
-- xyz-token-2       | abc-123
-- (فقط tokens المستخدم abc-123)
```

---

### Test 2: Admin يرى جميع tokens

```sql
-- سجل الدخول كـ Admin
SELECT * FROM user_tokens;

-- النتيجة المتوقعة:
-- token             | user_id
-- ------------------|---------
-- xyz-token-1       | abc-123
-- xyz-token-2       | abc-123
-- xyz-token-3       | def-456
-- xyz-token-4       | def-456
-- (جميع tokens لجميع المستخدمين)
```

---

### Test 3: المستخدم لا يستطيع رؤية tokens مستخدم آخر

```sql
-- مستخدم abc-123 يحاول رؤية tokens مستخدم def-456
SELECT * FROM user_tokens WHERE user_id = 'def-456';

-- النتيجة: 0 rows ❌
-- RLS يمنعه من رؤية tokens غيره
```

---

### Test 4: استخدام Function تتجاوز RLS

```sql
-- مستخدم عادي
SELECT * FROM get_expiring_products(60);

-- ✅ يعمل! يجلب جميع المنتجات
-- Function بـ SECURITY DEFINER تتجاوز RLS
```

---

### Test 5: Views ترث RLS

```sql
-- مستخدم عادي
SELECT * FROM distributor_products_expiring_soon;

-- ✅ يجلب البيانات حسب RLS policies على distributor_products
-- إذا كان distributor_products يسمح للجميع بالقراءة، ستعمل
```

---

## 🔐 أمثلة عملية

### مثال 1: حفظ FCM Token

```dart
// في Flutter
final userId = supabase.auth.currentUser!.id;
final token = 'fcm-token-12345';

// استدعاء Function
await supabase.rpc('upsert_user_token', params: {
  'p_user_id': userId,
  'p_token': token,
  'p_device_type': 'Android',
  'p_device_name': 'Samsung Galaxy S21',
});

// ✅ يعمل! حتى لو كان RLS مفعّل
// لأن Function بـ SECURITY DEFINER
```

---

### مثال 2: حذف Token عند تسجيل الخروج

```dart
// في Flutter
await supabase.rpc('delete_user_token', params: {
  'p_user_id': userId,
  'p_token': token,
});

// ✅ يحذف token للمستخدم الحالي فقط
// Function تتحقق من user_id داخلياً
```

---

### مثال 3: Admin يستعرض جميع tokens

```sql
-- في Supabase Dashboard (مسجل دخول كـ Admin)
SELECT 
  ut.user_id,
  u.email,
  ut.device_type,
  ut.device_name,
  ut.created_at
FROM user_tokens ut
JOIN auth.users u ON ut.user_id = u.id
ORDER BY ut.created_at DESC;

-- ✅ يرى الكل
```

---

### مثال 4: مستخدم عادي يستعرض tokens الخاصة به

```sql
-- مستخدم عادي في Supabase Dashboard
SELECT * FROM user_tokens;

-- ✅ يرى tokens الخاصة به فقط
```

---

## 🐛 Troubleshooting

### مشكلة: "new row violates row-level security policy"

**السبب:** حاولت إضافة/تحديث بيانات غير مسموح بها.

**الحل:**
```sql
-- تحقق من policies
SELECT * FROM pg_policies WHERE tablename = 'user_tokens';

-- تأكد من أن user_id يطابق auth.uid()
```

---

### مشكلة: Function لا تعمل

**السبب:** المستخدم لا يملك صلاحية EXECUTE.

**الحل:**
```sql
-- إعطاء صلاحية
GRANT EXECUTE ON FUNCTION function_name TO authenticated;
```

---

### مشكلة: View لا تُظهر بيانات

**السبب:** RLS على الجداول الأساسية تمنع الوصول.

**الحل:**
```sql
-- تحقق من policies على الجداول الأساسية
SELECT * FROM pg_policies WHERE tablename = 'distributor_products';

-- تأكد من وجود policy للقراءة
```

---

## 📁 الملفات

- ✅ `supabase/migrations/20250120_add_rls_notifications_views.sql` - RLS policies
- ✅ `RLS_POLICIES_GUIDE.md` - هذا الملف

---

## ✅ الخلاصة

### جدول `user_tokens`:
- ✅ المستخدم يرى ويعدل tokens الخاصة به فقط
- ✅ Admin يرى الكل

### جدول `notification_logs`:
- ✅ الجميع يمكنهم القراءة (للشفافية)
- ✅ فقط النظام يمكنه الكتابة
- ✅ Admin يمكنه التحديث والحذف

### Views:
- ✅ ترث RLS من الجداول الأساسية
- ✅ متاحة للقراءة لجميع المستخدمين المصادقين

### Functions:
- ✅ SECURITY DEFINER (تتجاوز RLS)
- ✅ متاحة للمستخدمين المصادقين
- ✅ log_notification فقط للنظام

---

**🔒 الأمان محمي بالكامل! 🎉**
