# ✅ جلب رقم الواتساب تلقائياً للعيادة

## الطلب 📝
عند إنشاء أو تحديث موقع العيادة، يتم جلب رقم الواتساب من جدول `users` ووضعه تلقائياً في `phone_number` في جدول `clinics`.

---

## الحل ✅

### تم تعديل دالة `upsert_clinic` في SQL:

#### قبل التعديل ❌:
```sql
CREATE OR REPLACE FUNCTION public.upsert_clinic(
  p_user_id uuid,
  p_clinic_name text,
  p_latitude double precision,
  p_longitude double precision,
  p_address text,
  p_phone_number text  -- ❌ مطلوب
)
```

**المشكلة**: كان يجب تمرير `phone_number` يدوياً.

---

#### بعد التعديل ✅:
```sql
CREATE OR REPLACE FUNCTION public.upsert_clinic(
  p_user_id uuid,
  p_clinic_name text,
  p_latitude double precision,
  p_longitude double precision,
  p_address text,
  p_phone_number text DEFAULT NULL  -- ✅ اختياري الآن
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
  END IF;

  INSERT INTO public.clinics (user_id, clinic_name, latitude, longitude, address, phone_number, location)
  VALUES (p_user_id, p_clinic_name, p_latitude, p_longitude, p_address, v_phone_number, ...)
  ON CONFLICT (user_id)
  DO UPDATE SET
    ...
    phone_number = EXCLUDED.phone_number,
    ...
END;
$$;
```

---

## المنطق 🔄

```
┌─────────────────────────────────────┐
│ 1. استدعاء upsert_clinic()          │
│    - مع أو بدون phone_number        │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 2. هل phone_number موجود؟           │
│    ├─ نعم → استخدمه                 │
│    └─ لا → جلب whatsapp_number       │
│            من جدول users            │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 3. حفظ/تحديث العيادة                │
│    - phone_number = whatsapp_number │
└─────────────────────────────────────┘
```

---

## التطبيق 🚀

### شغّل هذا في Supabase SQL Editor:

```sql
supabase/UPDATE_upsert_clinic_with_whatsapp.sql
```

### النتيجة المتوقعة:
```
========================================
✅ تم تحديث دالة upsert_clinic
✅ الآن يتم جلب رقم الواتساب تلقائياً
✅ phone_number = users.whatsapp_number

🧪 اختبر بإنشاء أو تحديث عيادة
========================================
```

---

## الاختبار 🧪

### في التطبيق:

1. ✅ افتح التطبيق كطبيب
2. ✅ انتقل إلى صفحة إضافة/تحديث العيادة
3. ✅ احفظ الموقع (بدون إدخال رقم الهاتف يدوياً)
4. ✅ افحص خريطة العيادات
5. ✅ انقر على علامة عيادتك
6. ✅ **يجب أن يظهر رقم الواتساب في "رقم الهاتف"!** 🎉

---

### في Supabase SQL Editor (للتأكد):

```sql
-- قبل الحفظ: افحص رقم الواتساب
SELECT id, display_name, whatsapp_number 
FROM users 
WHERE id = 'your-user-id';

-- بعد الحفظ: افحص العيادة
SELECT clinic_name, phone_number 
FROM clinics 
WHERE user_id = 'your-user-id';
```

**يجب أن يكون**: `clinics.phone_number = users.whatsapp_number`

---

## الميزات ✨

### 1. تلقائي بالكامل
لا حاجة لإدخال رقم الهاتف يدوياً - يتم جلبه من حساب المستخدم.

### 2. مرن
- إذا مررت `phone_number` → يستخدمه
- إذا لم تمرره (NULL) → يجلب `whatsapp_number` تلقائياً

### 3. متوافق مع الكود القديم
```dart
// الطريقة القديمة (مع phone_number) - تعمل
await _client.rpc('upsert_clinic', params: {
  'p_user_id': userId,
  'p_clinic_name': clinicName,
  'p_latitude': latitude,
  'p_longitude': longitude,
  'p_address': address,
  'p_phone_number': phoneNumber,  // ✅ يستخدمه
});

// الطريقة الجديدة (بدون phone_number) - تعمل أيضاً
await _client.rpc('upsert_clinic', params: {
  'p_user_id': userId,
  'p_clinic_name': clinicName,
  'p_latitude': latitude,
  'p_longitude': longitude,
  'p_address': address,
  // p_phone_number محذوف → ✅ يجلب whatsapp_number
});
```

---

## تحديث Dart Code (اختياري) 🔧

### في `clinic_repository.dart`:

يمكنك إزالة parameter `phoneNumber` تماماً:

#### قبل:
```dart
Future<bool> upsertClinic({
  required String userId,
  required String clinicName,
  required double latitude,
  required double longitude,
  String? address,
  String? phoneNumber,  // ❌ يمكن إزالته
}) async {
  try {
    await _client.rpc('upsert_clinic', params: {
      'p_user_id': userId,
      'p_clinic_name': clinicName,
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_address': address,
      'p_phone_number': phoneNumber,  // ❌
    });
    return true;
  } catch (e) {
    print('❌ Error upserting clinic: $e');
    return false;
  }
}
```

#### بعد:
```dart
Future<bool> upsertClinic({
  required String userId,
  required String clinicName,
  required double latitude,
  required double longitude,
  String? address,
  String? phoneNumber,  // ✅ اختياري - سيُستخدم فقط إذا مُرر
}) async {
  try {
    final params = {
      'p_user_id': userId,
      'p_clinic_name': clinicName,
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_address': address,
    };
    
    // إضافة phone_number فقط إذا كان موجود
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      params['p_phone_number'] = phoneNumber;
    }
    // إذا لم يُمرر، SQL function سيجلب whatsapp_number تلقائياً
    
    await _client.rpc('upsert_clinic', params: params);
    return true;
  } catch (e) {
    print('❌ Error upserting clinic: $e');
    return false;
  }
}
```

**ملاحظة**: الكود القديم سيعمل بدون تعديل! التحديث اختياري للوضوح فقط.

---

## الفوائد 🎯

### 1. تجربة مستخدم أفضل
- لا حاجة لإدخال رقم الهاتف يدوياً
- يتم جلبه تلقائياً من الحساب

### 2. اتساق البيانات
- رقم واحد (الواتساب) يُستخدم في كل مكان
- تجنب الاختلافات بين الأرقام

### 3. سهولة الصيانة
- إذا غيّر المستخدم رقم الواتساب
- يمكنه تحديث العيادة ليتم جلب الرقم الجديد

---

## الملفات 📁

| الملف | الوصف | الحالة |
|------|-------|--------|
| `UPDATE_upsert_clinic_with_whatsapp.sql` | ✅ **شغّل هذا** | جاهز |
| `04_upsert_clinic_function.sql` | ✅ محدّث | للمرجع |
| `AUTO_FETCH_WHATSAPP_FOR_CLINIC.md` | 📄 هذا الملف | توثيق |

---

## الخلاصة 📊

### قبل:
```
❌ يجب إدخال phone_number يدوياً
❌ قد يكون مختلف عن whatsapp_number
```

### بعد:
```
✅ يتم جلب whatsapp_number تلقائياً
✅ رقم واحد متسق
✅ تجربة مستخدم أفضل
```

---

**شغّل SQL وجرب!** 🚀

الآن عند إنشاء/تحديث العيادة، رقم الواتساب سيظهر تلقائياً في معلومات العيادة! 🎉
