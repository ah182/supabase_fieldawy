# 🔍 تشخيص: رقم الهاتف لا يظهر في معلومات العيادة

## المشكلة
عند النقر على علامة عيادة في الخريطة، تظهر جميع المعلومات ما عدا رقم الهاتف.

## الكود الحالي ✅

### في `_ClinicDetailsSheet.build()`:
```dart
_buildInfoRow(context, Icons.phone_outlined, 'Phone', clinic.clinicPhoneNumber),
```

### في `_buildInfoRow()`:
```dart
Widget _buildInfoRow(BuildContext context, IconData icon, String title, String? value) {
  if (value == null || value.isEmpty) return const SizedBox.shrink();
  // عرض الصف
}
```

**المنطق**: إذا كان `clinic.clinicPhoneNumber` هو `null` أو فارغ، لا يظهر الصف.

---

## الأسباب المحتملة 🔍

### 1. البيانات في قاعدة البيانات فارغة
- ربما عمود `phone_number` في جدول `clinics` فارغ
- أو `null` للعيادات الموجودة

### 2. مشكلة في parsing البيانات
- الـ view يستخدم `phone_number as clinic_phone_number`
- الكود Dart يقرأ `map['clinic_phone_number']`

---

## خطوات التشخيص 🔧

### الخطوة 1: تحقق من البيانات في Supabase

في **Supabase SQL Editor**:
```sql
SELECT clinic_name, phone_number, clinic_phone_number 
FROM clinics_with_doctor_info 
LIMIT 10;
```

**النتيجة المتوقعة**:
- إذا كانت `phone_number` أو `clinic_phone_number` فارغة → **المشكلة في البيانات**
- إذا كانت موجودة → **المشكلة في الكود**

---

### الخطوة 2: تحقق من Console Logs

أضفت debug prints في الكود:
```dart
print('🔍 Clinic: ${clinic.clinicName}');
print('🔍 Phone Number: ${clinic.clinicPhoneNumber}');
print('🔍 Phone is null: ${clinic.clinicPhoneNumber == null}');
print('🔍 Phone isEmpty: ${clinic.clinicPhoneNumber?.isEmpty}');
```

**شغّل التطبيق** وانقر على علامة عيادة، ثم افحص Console:

#### إذا رأيت:
```
🔍 Phone Number: null
🔍 Phone is null: true
```
**الحل**: البيانات غير موجودة - يجب إضافة أرقام الهواتف للعيادات

#### إذا رأيت:
```
🔍 Phone Number: 0123456789
🔍 Phone is null: false
🔍 Phone isEmpty: false
```
**الحل**: البيانات موجودة لكن هناك مشكلة في العرض

---

## الحلول المحتملة 🚀

### الحل 1: إذا كانت البيانات فارغة

#### تحديث البيانات في Supabase:
```sql
-- تحديث العيادات بأرقام هواتف تجريبية
UPDATE clinics 
SET phone_number = '0123456789' 
WHERE phone_number IS NULL OR phone_number = '';

-- أو تحديث عيادة معينة
UPDATE clinics 
SET phone_number = '0100-111-2222' 
WHERE id = 'clinic-id-here';
```

#### في التطبيق (إذا كانت العيادة للمستخدم الحالي):
يمكن إضافة صفحة تعديل معلومات العيادة.

---

### الحل 2: إذا كانت المشكلة في العرض

#### تحديث `_buildInfoRow` لعرض رسالة بديلة:

```dart
Widget _buildInfoRow(BuildContext context, IconData icon, String title, String? value, {bool showIfEmpty = false}) {
  if (value == null || value.isEmpty) {
    if (!showIfEmpty) return const SizedBox.shrink();
    // عرض رسالة "غير متوفر"
    value = 'غير متوفر';
  }
  
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: value == 'غير متوفر' ? Colors.grey : null,
                  fontStyle: value == 'غير متوفر' ? FontStyle.italic : null,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

ثم استخدمه:
```dart
_buildInfoRow(context, Icons.phone_outlined, 'Phone', clinic.clinicPhoneNumber, showIfEmpty: true),
```

---

### الحل 3: إضافة زر للاتصال مباشرة

```dart
Widget _buildPhoneRow(BuildContext context, String? phoneNumber) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.phone_outlined, color: Theme.of(context).primaryColor, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            phoneNumber ?? 'رقم الهاتف غير متوفر',
            style: TextStyle(
              fontSize: 16,
              color: phoneNumber == null ? Colors.grey : null,
            ),
          ),
        ),
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            tooltip: 'اتصل الآن',
            onPressed: () async {
              final url = Uri.parse('tel:$phoneNumber');
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لا يمكن فتح تطبيق الاتصال')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطأ: $e')),
                );
              }
            },
          ),
      ],
    ),
  );
}
```

استخدمه بدلاً من `_buildInfoRow` لرقم الهاتف:
```dart
_buildPhoneRow(context, clinic.clinicPhoneNumber),
```

---

## التحقق السريع ⚡

### في Terminal:
```bash
flutter run
```

### في Console ابحث عن:
```
🔍 Clinic: ...
🔍 Phone Number: ...
```

### في Supabase SQL Editor:
```sql
SELECT * FROM clinics_with_doctor_info WHERE clinic_phone_number IS NOT NULL;
```

---

## الملفات المحدثة 📁

| الملف | التغيير | الحالة |
|------|---------|--------|
| `clinics_map_screen.dart` | إضافة debug prints | ✅ محدث |
| `DEBUG_CLINIC_PHONE.md` | هذا الملف - التشخيص | ✅ جديد |

---

## الخطوة التالية 🎯

1. ✅ شغّل التطبيق
2. ✅ انقر على علامة عيادة
3. ✅ افحص Console logs
4. ✅ أخبرني بالنتيجة:
   - `Phone Number: null` → البيانات فارغة
   - `Phone Number: 0123456789` → البيانات موجودة

وسأعطيك الحل المناسب! 🚀
