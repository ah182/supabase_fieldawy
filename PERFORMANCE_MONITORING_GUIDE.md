# 🚀 Performance & Error Monitoring Guide

## 📊 **نظام مراقبة الأداء والأخطاء**

---

## 🎯 **الأدوات المتاحة:**

### **1️⃣ Firebase Performance Monitoring** ⭐⭐⭐⭐⭐
**مجاني - مدمج مع Firebase**

#### **المميزات:**
- ✅ **App Start Time** - وقت بدء التطبيق
- ✅ **Screen Rendering** - سرعة عرض الشاشات
- ✅ **Network Requests** - مراقبة API calls
- ✅ **Custom Traces** - قياس أداء أي كود
- ✅ **Automatic Traces** - تتبع تلقائي

#### **التثبيت:**
```yaml
dependencies:
  firebase_performance: ^0.10.0
```

#### **الاستخدام:**
```dart
// 1. App start trace (automatic)
// يعمل تلقائياً

// 2. Custom trace
final trace = FirebasePerformance.instance.newTrace('load_products');
await trace.start();
// Your code here
await loadProducts();
await trace.stop();

// 3. HTTP request trace (automatic)
// يتتبع كل HTTP requests تلقائياً
```

#### **Dashboard:**
- Firebase Console → Performance
- رسوم بيانية لكل المقاييس
- تنبيهات عند بطء الأداء

---

### **2️⃣ Firebase Crashlytics** ⭐⭐⭐⭐⭐
**مجاني - تتبع الأخطاء**

#### **المميزات:**
- ✅ **Crash Reports** - تقارير Crashes
- ✅ **Non-fatal Errors** - أخطاء غير قاتلة
- ✅ **Stack Traces** - معلومات تفصيلية
- ✅ **User Impact** - عدد المستخدمين المتأثرين
- ✅ **Real-time Alerts** - تنبيهات فورية

#### **التثبيت:**
```yaml
dependencies:
  firebase_crashlytics: ^4.1.3
```

#### **الاستخدام:**
```dart
// في main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Enable Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  
  runApp(MyApp());
}

// تسجيل خطأ يدوياً
try {
  // Your code
} catch (e, stack) {
  FirebaseCrashlytics.instance.recordError(e, stack);
}

// إضافة context
FirebaseCrashlytics.instance.setCustomKey('user_role', 'doctor');
FirebaseCrashlytics.instance.setUserId(userId);
```

---

### **3️⃣ Sentry** ⭐⭐⭐⭐⭐
**مجاني حتى 5,000 event/شهر**

#### **المميزات:**
- ✅ **Error Tracking** - تتبع دقيق للأخطاء
- ✅ **Performance Monitoring** - مراقبة الأداء
- ✅ **Release Tracking** - تتبع الإصدارات
- ✅ **Breadcrumbs** - سجل أحداث قبل الخطأ
- ✅ **Source Maps** - ربط بالكود الأصلي

#### **التثبيت:**
```yaml
dependencies:
  sentry_flutter: ^8.9.0
```

#### **الاستخدام:**
```dart
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'YOUR_SENTRY_DSN';
      options.tracesSampleRate = 1.0; // 100% performance monitoring
      options.enableAutoPerformanceTracing = true;
    },
    appRunner: () => runApp(MyApp()),
  );
}

// تسجيل خطأ
try {
  // Code
} catch (e, stack) {
  Sentry.captureException(e, stackTrace: stack);
}
```

---

### **4️⃣ Custom Error Logging (Supabase)** ⭐⭐⭐⭐
**مجاني - تحكم كامل**

#### **المميزات:**
- ✅ **Full Control** - تحكم كامل في البيانات
- ✅ **Custom Dashboard** - لوحة تحكم مخصصة
- ✅ **Integration** - متكامل مع Dashboard
- ✅ **Privacy** - بياناتك عندك

---

## 🛠️ **الحل المقترح (الأفضل):**

### **Setup كامل:**

```yaml
dependencies:
  # Performance
  firebase_performance: ^0.10.0
  
  # Error Tracking
  firebase_crashlytics: ^4.1.3
  # OR
  sentry_flutter: ^8.9.0
  
  # Network Monitoring
  dio: ^5.4.0 # بدل http
  pretty_dio_logger: ^1.3.1
```

---

## 📊 **Custom Performance Monitoring Widget**

سننشئ widget يعرض في Dashboard:

### **المقاييس:**
```
📊 Performance Metrics (Last 24h)
├── Average API Response Time: 245ms
├── Slowest API: /products (890ms)
├── Total API Calls: 12,450
├── Error Rate: 0.5% (62 errors)
├── App Crashes: 2
└── Active Users: 142
```

### **Error Logs:**
```
🐛 Recent Errors (Last 50)
├── TypeError in ProductScreen
│   ├── Users affected: 5
│   ├── First seen: 2 hours ago
│   └── Stack trace: [View]
├── Network timeout in getOffers
│   ├── Users affected: 12
│   ├── First seen: 5 hours ago
│   └── Stack trace: [View]
```

---

## 🗄️ **Database Schema (Supabase):**

```sql
-- Error Logs
CREATE TABLE error_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  error_type TEXT NOT NULL,
  error_message TEXT NOT NULL,
  stack_trace TEXT,
  user_id TEXT,
  user_role TEXT,
  device_info JSONB,
  app_version TEXT,
  route TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Performance Logs
CREATE TABLE performance_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_type TEXT NOT NULL, -- 'api_call', 'screen_load', 'custom'
  metric_name TEXT NOT NULL,
  duration_ms INT,
  success BOOLEAN DEFAULT true,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_error_logs_created ON error_logs(created_at DESC);
CREATE INDEX idx_error_logs_type ON error_logs(error_type);
CREATE INDEX idx_performance_logs_created ON performance_logs(created_at DESC);
CREATE INDEX idx_performance_logs_type ON performance_logs(metric_type);
```

---

## 🎯 **Implementation Plan:**

### **Phase 1: Error Tracking (اليوم)**
1. ✅ إضافة Firebase Crashlytics
2. ✅ إنشاء error_logs table
3. ✅ Error handler عام
4. ✅ Error Logs Viewer widget

### **Phase 2: Performance Monitoring (غداً)**
1. ✅ إضافة Firebase Performance
2. ✅ إنشاء performance_logs table
3. ✅ API interceptor
4. ✅ Performance Dashboard widget

### **Phase 3: Analytics Integration (بعد غد)**
1. ✅ ربط Errors مع User Activity
2. ✅ Alerts للأخطاء الحرجة
3. ✅ Trends & Reports

---

## 🚀 **Quick Start (الآن):**

### **Option 1: Firebase (الأسهل)**

```bash
# 1. Add to pubspec.yaml
flutter pub add firebase_crashlytics firebase_performance

# 2. Configure in main.dart
# (سأوفر الكود الكامل)

# 3. Deploy
flutter build web --release
firebase deploy
```

### **Option 2: Custom (أكثر تحكم)**

```bash
# 1. Create tables in Supabase
# (سأوفر SQL script)

# 2. Add error handler
# (سأوفر الكود)

# 3. Add widgets to Dashboard
# (سأوفر Widgets)
```

---

## 📈 **Metrics to Track:**

### **Performance:**
- ⚡ App Start Time
- 🌐 API Response Times
- 📱 Screen Load Times
- 💾 Database Query Times
- 🖼️ Image Load Times

### **Errors:**
- 💥 Crashes
- ⚠️ Exceptions
- 🌐 Network Errors
- 🔒 Auth Errors
- 📝 Validation Errors

### **User Experience:**
- 👥 Active Users
- 📊 Session Duration
- 🔄 Refresh Rate
- ❌ Error Rate per User
- 📍 Errors by Location

---

## 🎨 **Dashboard Widgets (سأنشئها):**

### **1. Performance Overview:**
```
┌─────────────────────────────────┐
│ ⚡ Performance Overview         │
├─────────────────────────────────┤
│ Avg Response Time: 245ms        │
│ Total API Calls: 12,450         │
│ Success Rate: 99.5%             │
│ Active Users: 142               │
└─────────────────────────────────┘
```

### **2. Error Dashboard:**
```
┌─────────────────────────────────┐
│ 🐛 Errors & Crashes             │
├─────────────────────────────────┤
│ Last 24h: 12 errors             │
│ Crashes: 0                      │
│ Most Common: TypeError (5)      │
│ [View All Errors →]             │
└─────────────────────────────────┘
```

### **3. API Performance:**
```
┌─────────────────────────────────┐
│ 🌐 API Performance              │
├─────────────────────────────────┤
│ /products     245ms  ✅         │
│ /users        189ms  ✅         │
│ /offers       890ms  ⚠️         │
└─────────────────────────────────┘
```

---

## 🎯 **عايز أنفذ أي Option؟**

### **A. Firebase (سريع وسهل)**
- أضيف Firebase Performance + Crashlytics
- جاهز في 10 دقائق
- يعرض في Firebase Console

### **B. Custom Dashboard (تحكم كامل)**
- أنشئ جداول في Supabase
- أنشئ Widgets في Dashboard
- كل شيء عندك

### **C. Both (الأفضل!)**
- Firebase للتتبع السريع
- Custom Dashboard للعرض الجميل
- أفضل من الاتنين

---

**قرر وأنفذ! 🚀**
