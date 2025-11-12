# 🔧 إرشادات إصلاح جميع أخطاء .when()

## 🎯 المشكلة
```
NoSuchMethodError: 'when'
Receiver: Instance of 'AsyncData<List<...>>'
```

يحدث في ملفات متعددة!

---

## ✅ الحل السريع - Pattern Matching

### استبدل هذا النمط في جميع الملفات:

#### القديم (لا يعمل):
```dart
return asyncValue.when(
  loading: () => LoadingWidget(),
  error: (err, stack) => ErrorWidget(),
  data: (value) {
    // use value
    return ContentWidget();
  },
);
```

#### الجديد (يعمل):
```dart
// Handle loading
if (asyncValue.isLoading && !asyncValue.hasValue) {
  return LoadingWidget();
}

// Handle error
if (asyncValue.hasError && !asyncValue.hasValue) {
  return ErrorWidget();
}

// Handle data
if (asyncValue.hasValue) {
  final value = asyncValue.value!;
  // use value
  return ContentWidget();
}

// Fallback
return LoadingWidget();
```

---

## 📁 الملفات التي تحتاج إصلاح

### ✅ تم إصلاحها:
1. ✅ `analytics_repository.dart`
2. ✅ `top_performers_widget.dart`
3. ✅ `system_health_widget.dart`
4. ✅ `geographic_distribution_widget.dart`
5. ✅ `advanced_search_widget.dart`
6. ✅ `pending_approvals_widget.dart`

### ⚠️ تحتاج إصلاح:
7. ⚠️ `user_growth_analytics.dart`
8. ⚠️ `recent_activity_timeline.dart`
9. ⚠️ `performance_monitor_widget.dart`
10. ⚠️ `offers_tracker_widget.dart`
11. ⚠️ `error_logs_viewer.dart`
12. ⚠️ `users_management_screen.dart`
13. ⚠️ `product_management_screen.dart`
14. ⚠️ `mobile_admin_dashboard_screen.dart`
15. ⚠️ `admin_dashboard_screen.dart`

---

## 🚀 إصلاح سريع

### للملفات المتبقية، افتح كل ملف وابحث عن:
```dart
.when(
```

### واستبدله بـ:
```dart
// Pattern matching approach
if (asyncValue.isLoading && !asyncValue.hasValue) {
  return /* loading widget */;
}
if (asyncValue.hasError && !asyncValue.hasValue) {
  return /* error widget */;
}
if (asyncValue.hasValue) {
  final data = asyncValue.value!;
  // use data
  return /* content widget */;
}
return /* fallback */;
```

---

## 💡 نصيحة

إذا كان الملف كبير جداً (مثل `product_management_screen.dart` 3000+ line):

### خيار 1: إصلاح تدريجي
- ابحث عن كل `.when(` في الملف
- استبدل واحد واحد

### خيار 2: تجاهل الـ widget
- إذا كان widget غير مستخدم حالياً، اتركه

### خيار 3: استخدام try-catch
```dart
Widget buildWidget(AsyncValue asyncValue) {
  try {
    if (asyncValue.hasValue) {
      return ContentWidget(asyncValue.value!);
    }
  } catch (e) {
    // fallback
  }
  return LoadingWidget();
}
```

---

## 🎯 الأولوية

### ابدأ بالملفات المستخدمة فعلاً:
1. **High Priority:**
   - `users_management_screen.dart`
   - `product_management_screen.dart`
   - `admin_dashboard_screen.dart`
   - `mobile_admin_dashboard_screen.dart`

2. **Medium Priority:**
   - `offers_tracker_widget.dart`
   - `user_growth_analytics.dart`
   - `recent_activity_timeline.dart`

3. **Low Priority:**
   - `performance_monitor_widget.dart`
   - `error_logs_viewer.dart`

---

## 🧪 الاختبار

بعد كل إصلاح:
```bash
flutter analyze lib/features/admin_dashboard/
```

تأكد من:
- ✅ لا أخطاء (0 errors)
- ℹ️ Warnings فقط (withOpacity - مقبولة)

---

## 🎊 النتيجة المطلوبة

```bash
flutter analyze lib/features/admin_dashboard/
✅ X warnings (withOpacity فقط)
✅ 0 errors
```

---

**ملاحظة:** الملفات الكبيرة جداً مثل `product_management_screen.dart` قد تستغرق وقتاً، لكن الإصلاح ضروري لإزالة جميع الأخطاء!
