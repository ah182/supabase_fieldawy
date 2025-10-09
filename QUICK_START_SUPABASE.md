# 🚀 دليل سريع - Supabase Notifications

## ✨ الحل الأكثر احترافية!

**لن تحتاج إدخال Token أبداً + إرسال لجميع المستخدمين!**

---

## 📋 4 خطوات سريعة

### 1️⃣ تطبيق SQL Migration

افتح Supabase Dashboard > SQL Editor والصق محتوى:
```
supabase/migrations/20250120_create_user_tokens.sql
```

ثم اضغط **Run**

---

### 2️⃣ أضف Supabase Credentials

افتح `send_notification_supabase.js` وعدّل:

```javascript
const SUPABASE_URL = "https://your-project.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = "your-service-role-key";
```

**من أين أحصل عليهم؟**
- Supabase Dashboard > Settings > API
- انسخ `URL` و `service_role` key

---

### 3️⃣ ثبّت المكتبات

```bash
npm install
```

---

### 4️⃣ سجّل دخول في التطبيق

- افتح التطبيق
- سجّل دخول
- ✅ Token يُحفظ تلقائياً!

---

## 🎉 جاهز! أرسل إشعار

```bash
npm run supabase:all:order
```

**سيرسل لجميع من سجّل دخول في التطبيق!** 🚀

---

## 📊 الأوامر المتاحة

```bash
# إرسال لجميع المستخدمين
npm run supabase:all:order   # طلب 🟢
npm run supabase:all:offer   # عرض 🟠
npm run supabase:all:general # عام 🔵

# إرسال لمستخدم محدد
node send_notification_supabase.js user order USER_UUID
```

---

## 🆚 لماذا Supabase؟

| الميزة | Topics | Supabase |
|--------|--------|----------|
| لا تحتاج Token | ✅ | ✅ |
| إرسال لجميع المستخدمين | ✅ | ✅ |
| إرسال لمستخدم محدد | ❌ | ✅ |
| تتبع الأجهزة | ❌ | ✅ |
| احترافية | جيد | ممتاز |

**🏆 Supabase = Topics + إمكانيات أكثر!**

---

## 🔍 التحقق من النجاح

### في التطبيق (Console):
```
✅ تم حفظ FCM Token في Supabase بنجاح
   User ID: abc-123...
   Device: Android
```

### في Supabase Dashboard:
```sql
SELECT * FROM user_tokens;
```

### عند الإرسال:
```
✅ تم الحصول على 5 token من Supabase
📱 سيتم الإرسال إلى 5 جهاز
✅ نجح: 5 | ❌ فشل: 0
```

---

## 📚 للتفاصيل الكاملة

راجع `SUPABASE_NOTIFICATIONS_GUIDE.md`

---

**🎯 خلاص! ما عاد تحتاج تدخل Token يدوياً أبداً!**
