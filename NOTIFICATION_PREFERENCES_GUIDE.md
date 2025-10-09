# 🔔 دليل إعدادات الإشعارات

## 📋 الميزة الجديدة

تم إضافة صفحة إعدادات الإشعارات التي تسمح للمستخدمين بالتحكم في أنواع الإشعارات التي يريدون استلامها!

---

## ✨ المميزات:

### 4 أنواع من الإشعارات يمكن التحكم فيها:

1. **💰 تحديثات الأسعار (Price Updates)**
   - إشعارات عند تحديث أسعار المنتجات

2. **⚠️ منتجات قاربت على الانتهاء (Expiring Products)**
   - إشعارات للمنتجات التي تنتهي صلاحيتها خلال سنة

3. **🎁 العروض (Offers)**
   - إشعارات العروض والخصومات الجديدة

4. **🔧 الأدوات الجراحية (Surgical Tools)**
   - إشعارات الأدوات الجراحية الجديدة

---

## 🚀 كيفية الوصول للصفحة:

1. افتح التطبيق
2. اذهب إلى **البروفايل** (Profile)
3. اضغط على **الإشعارات** (Notifications)
4. ستظهر صفحة الإعدادات مع 4 Toggle Buttons

---

## 🔧 الإعداد الأولي:

### 1️⃣ تشغيل Migration في Supabase:

```bash
# الطريقة 1: من Dashboard
1. افتح Supabase Dashboard
2. اذهب إلى SQL Editor
3. انسخ محتوى الملف: supabase/migrations/20250121_create_notification_preferences.sql
4. نفّذ الـ SQL
5. تحقق من إنشاء الجدول بنجاح

# الطريقة 2: من CLI (إذا كان لديك)
supabase db push
```

### 2️⃣ التحقق من الجدول:

في Supabase Dashboard > Table Editor، يجب أن تشاهد جدول جديد اسمه:
```
notification_preferences
```

**الأعمدة:**
- `id` - UUID
- `user_id` - UUID (مرتبط بـ auth.users)
- `price_action` - BOOLEAN
- `expire_soon` - BOOLEAN
- `offers` - BOOLEAN
- `surgical_tools` - BOOLEAN
- `created_at` - TIMESTAMP
- `updated_at` - TIMESTAMP

### 3️⃣ التحقق من RLS Policies:

يجب أن تشاهد 4 policies:
- ✅ Users can view own notification preferences
- ✅ Users can insert own notification preferences
- ✅ Users can update own notification preferences
- ✅ Users can delete own notification preferences

---

## 📱 كيفية الاستخدام:

### للمستخدم:

1. **افتح صفحة الإعدادات:**
   - Profile > Notifications

2. **فعّل أو عطّل أي نوع من الإشعارات:**
   - Toggle ON ✅ = سأستقبل هذه الإشعارات
   - Toggle OFF ❌ = لن أستقبل هذه الإشعارات

3. **التغييرات تُحفظ تلقائياً:**
   - لا تحتاج لزر "حفظ"
   - سترى رسالة "تم حفظ الإعدادات" عند كل تغيير

---

## 🧪 الاختبار:

### Test 1: تعطيل إشعارات الأسعار

```sql
-- 1. عطّل إشعارات Price Action من الصفحة
-- 2. حدّث سعر منتج
UPDATE distributor_products
SET price = price + 1
WHERE id = (SELECT id FROM distributor_products LIMIT 1);

-- النتيجة: لن يظهر إشعار ✅
```

### Test 2: تعطيل إشعارات العروض

```sql
-- 1. عطّل إشعارات Offers من الصفحة
-- 2. أضف عرض جديد
INSERT INTO offers (...)

-- النتيجة: لن يظهر إشعار ✅
```

### Test 3: تفعيل كل الإشعارات

```
-- 1. فعّل جميع الـ Toggles
-- 2. اختبر أي إشعار

-- النتيجة: ستظهر جميع الإشعارات ✅
```

---

## 🎯 كيف تعمل الفلترة:

### في Flutter (main.dart):

```dart
// قبل عرض أي إشعار:
if (!await _shouldShowNotification(screen)) {
  print('⏭️ تم تخطي الإشعار (معطّل في الإعدادات)');
  return;
}

// يفحص:
Future<bool> _shouldShowNotification(String screen) async {
  // يحدد نوع الإشعار من screen name
  // يجلب التفضيلات من Supabase
  // يرجع true/false
}
```

### في Supabase:

```sql
-- البيانات محفوظة لكل مستخدم:
SELECT * FROM notification_preferences WHERE user_id = 'user_id';

-- النتيجة:
{
  "price_action": true,
  "expire_soon": false,  -- معطّل
  "offers": true,
  "surgical_tools": true
}
```

---

## 📊 الإعدادات الافتراضية:

عند أول استخدام، **جميع الإشعارات مفعّلة**:
- ✅ Price Action = مفعّل
- ✅ Expire Soon = مفعّل
- ✅ Offers = مفعّل
- ✅ Surgical Tools = مفعّل

المستخدم يمكنه تعديلها حسب رغبته.

---

## 🔒 الأمان (RLS):

- ✅ كل مستخدم يرى إعداداته فقط
- ✅ لا يمكن تعديل إعدادات مستخدمين آخرين
- ✅ تُحذف الإعدادات تلقائياً عند حذف المستخدم (ON DELETE CASCADE)

---

## 🐛 استكشاف الأخطاء:

### المشكلة: لا تظهر صفحة الإعدادات

**الحل:**
```bash
# 1. تأكد من flutter clean
flutter clean
flutter pub get

# 2. أعد build التطبيق
flutter run
```

### المشكلة: خطأ في حفظ الإعدادات

**الحل:**
1. تحقق من RLS Policies في Supabase
2. تحقق من أن المستخدم مسجل دخول
3. افحص Console logs في Supabase Dashboard

### المشكلة: الإشعارات تظهر رغم التعطيل

**الحل:**
1. افحص Logs في التطبيق (Console)
2. تأكد من وجود السطر: `⏭️ تم تخطي الإشعار`
3. إذا لم يظهر، تحقق من:
   - `notification_preferences` table موجود
   - البيانات محفوظة في الجدول
   - RLS policies صحيحة

---

## 📝 الملفات المضافة:

1. **Flutter:**
   - `lib/features/notifications/notification_preferences_screen.dart`
   - `lib/services/notification_preferences_service.dart`
   - تعديل `lib/main.dart` (إضافة فلترة)
   - تعديل `lib/features/profile/presentation/screens/profile_screen.dart`

2. **Supabase:**
   - `supabase/migrations/20250121_create_notification_preferences.sql`

3. **Translations:**
   - تحديث `assets/translations/ar.json`
   - تحديث `assets/translations/en.json`

---

## ✅ الخلاصة:

1. ✅ Migration جاهز في Supabase
2. ✅ صفحة الإعدادات جاهزة
3. ✅ الفلترة تعمل في الخلفية والمقدمة
4. ✅ الترجمات جاهزة (عربي وإنجليزي)
5. ✅ RLS Policies محمية

**الآن يمكن للمستخدمين التحكم الكامل في إشعاراتهم! 🎉**
