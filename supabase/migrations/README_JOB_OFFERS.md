# Job Offers System Documentation

## Overview
نظام كامل لإدارة عروض التوظيف في تطبيق Fieldawy Store للأطباء البيطريين والموزعين.

## Database Schema

### Table: `job_offers`

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| `id` | UUID | معرف فريد للعرض | Primary Key, Auto-generated |
| `user_id` | UUID | معرف المستخدم صاحب العرض | Foreign Key to auth.users, NOT NULL |
| `title` | TEXT | عنوان الوظيفة | 10-200 characters |
| `description` | TEXT | وصف الوظيفة | 50-2000 characters |
| `phone` | TEXT | رقم الهاتف | Egyptian format: 01XXXXXXXXX |
| `status` | TEXT | حالة العرض | active/closed/expired |
| `views_count` | INTEGER | عدد المشاهدات | Default: 0 |
| `created_at` | TIMESTAMPTZ | تاريخ الإنشاء | Auto-generated |
| `updated_at` | TIMESTAMPTZ | تاريخ آخر تحديث | Auto-updated |

## Security (RLS Policies)

### Select Policies
1. **job_offers_select_active**: أي شخص يمكنه رؤية العروض النشطة
2. **job_offers_select_own**: المستخدمون يمكنهم رؤية جميع عروضهم بكل الحالات

### Insert Policy
- **job_offers_insert_authenticated**: المستخدمون المسجلون فقط يمكنهم إضافة عروض

### Update Policy
- **job_offers_update_own**: المستخدمون يمكنهم تعديل عروضهم فقط

### Delete Policy
- **job_offers_delete_own**: المستخدمون يمكنهم حذف عروضهم فقط

## Functions

### 1. `get_all_job_offers()`
جلب جميع العروض النشطة مع معلومات صاحب العرض.

```sql
SELECT * FROM public.get_all_job_offers();
```

**Returns:**
- id, user_id, user_name, title, description, phone, status, views_count, created_at, updated_at

---

### 2. `get_my_job_offers(p_user_id UUID)`
جلب عروض مستخدم معين (يجب أن يكون المستخدم الحالي).

```sql
SELECT * FROM public.get_my_job_offers(auth.uid());
```

**Parameters:**
- `p_user_id`: معرف المستخدم

**Returns:**
- id, user_id, title, description, phone, status, views_count, created_at, updated_at

---

### 3. `create_job_offer(p_title TEXT, p_description TEXT, p_phone TEXT)`
إنشاء عرض توظيف جديد.

```sql
SELECT public.create_job_offer(
    'طبيب بيطري للعمل في عيادة',
    'مطلوب طبيب بيطري خبرة 3 سنوات...',
    '01012345678'
);
```

**Parameters:**
- `p_title`: عنوان الوظيفة (10-200 حرف)
- `p_description`: وصف الوظيفة (50-2000 حرف)
- `p_phone`: رقم الهاتف (صيغة مصرية: 01XXXXXXXXX)

**Returns:** UUID للعرض المُنشأ

**Validations:**
- العنوان: 10-200 حرف
- الوصف: 50-2000 حرف
- رقم الهاتف: يجب أن يبدأ بـ 01 ويتكون من 11 رقم

---

### 4. `update_job_offer(p_job_id UUID, p_title TEXT, p_description TEXT, p_phone TEXT)`
تحديث عرض توظيف موجود.

```sql
SELECT public.update_job_offer(
    'job-id-here',
    'عنوان محدث',
    'وصف محدث...',
    '01098765432'
);
```

**Parameters:**
- `p_job_id`: معرف العرض
- `p_title`: عنوان جديد
- `p_description`: وصف جديد
- `p_phone`: رقم هاتف جديد

**Returns:** TRUE إذا نجح التحديث

---

### 5. `delete_job_offer(p_job_id UUID)`
حذف عرض توظيف.

```sql
SELECT public.delete_job_offer('job-id-here');
```

**Parameters:**
- `p_job_id`: معرف العرض

**Returns:** TRUE إذا نجح الحذف

---

### 6. `increment_job_views(p_job_id UUID)`
زيادة عداد المشاهدات للعرض.

```sql
SELECT public.increment_job_views('job-id-here');
```

**Parameters:**
- `p_job_id`: معرف العرض

---

### 7. `close_job_offer(p_job_id UUID)`
إغلاق عرض توظيف (تغيير الحالة إلى closed).

```sql
SELECT public.close_job_offer('job-id-here');
```

**Parameters:**
- `p_job_id`: معرف العرض

**Returns:** TRUE إذا نجح الإغلاق

---

## Views

### `active_job_offers`
عرض سهل لجلب العروض النشطة فقط مع معلومات صاحب العرض.

```sql
SELECT * FROM public.active_job_offers;
```

## Usage Examples in Flutter/Dart

### 1. Get All Active Jobs
```dart
final response = await supabase
    .from('job_offers')
    .select('*, users(name)')
    .eq('status', 'active')
    .order('created_at', ascending: false);
```

أو استخدام الـ Function:
```dart
final response = await supabase.rpc('get_all_job_offers');
```

### 2. Get My Jobs
```dart
final userId = supabase.auth.currentUser?.id;
final response = await supabase.rpc('get_my_job_offers', params: {'p_user_id': userId});
```

### 3. Create Job Offer
```dart
final response = await supabase.rpc('create_job_offer', params: {
  'p_title': 'طبيب بيطري للعمل في عيادة',
  'p_description': 'مطلوب طبيب بيطري...',
  'p_phone': '01012345678',
});
```

### 4. Update Job Offer
```dart
final response = await supabase.rpc('update_job_offer', params: {
  'p_job_id': jobId,
  'p_title': 'عنوان محدث',
  'p_description': 'وصف محدث...',
  'p_phone': '01098765432',
});
```

### 5. Delete Job Offer
```dart
final response = await supabase.rpc('delete_job_offer', params: {
  'p_job_id': jobId,
});
```

### 6. Close Job Offer
```dart
final response = await supabase.rpc('close_job_offer', params: {
  'p_job_id': jobId,
});
```

## Indexes
تم إنشاء الـ indexes التالية لتحسين الأداء:
- `idx_job_offers_user_id`: للبحث حسب المستخدم
- `idx_job_offers_status`: للبحث حسب الحالة
- `idx_job_offers_created_at`: للترتيب حسب التاريخ
- `idx_job_offers_user_status`: للبحث المركب

## Migration
لتطبيق الـ migration:

```bash
# إذا كنت تستخدم Supabase CLI
supabase db push

# أو قم بتشغيل الملف مباشرة في Supabase Dashboard
```

## Testing
بعد تطبيق الـ migration، يمكنك اختبار النظام:

1. إضافة عرض توظيف جديد
2. عرض جميع العروض النشطة
3. تعديل العرض
4. إغلاق العرض
5. حذف العرض

## Notes
- جميع العروض تُنشأ بحالة `active` افتراضياً
- المستخدمون يمكنهم رؤية عروضهم بكل الحالات
- الزوار (غير المسجلين) يمكنهم رؤية العروض النشطة فقط
- يتم تحديث `updated_at` تلقائياً عند أي تعديل
- رقم الهاتف يجب أن يكون بالصيغة المصرية: 01XXXXXXXXX
