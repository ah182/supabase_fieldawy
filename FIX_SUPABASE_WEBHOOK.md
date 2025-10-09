# 🔧 إصلاح: Supabase Webhook لا يُرسل

## ❌ المشكلة

- ✅ localtunnel يعمل
- ✅ Server يعمل
- ✅ SQL query نجح
- ❌ Webhook لم يُرسل (Logs فارغة)
- ❌ لا يوجد إشعار

---

## 💡 السبب

**Webhook غير مُفعّل أو مُعدّ بشكل خاطئ!**

---

## ✅ الحل الكامل (خطوة بخطوة)

### 1️⃣ احذف Webhook القديم

**في Supabase Dashboard:**

1. اذهب إلى **Database** > **Webhooks**
2. ابحث عن webhook للـ `surgical_tools`
3. اضغط على أيقونة **🗑️ Delete** أو **⋮ > Delete**
4. أكّد الحذف

---

### 2️⃣ أضف Webhook جديد (بالضبط)

**اضغط: Create a new hook**

---

#### ⚙️ الإعدادات (بالتفصيل):

**1. Hook Details:**
```
Name: surgical_tools_notifications
```

**2. Conditions:**
```
Schema: public
Table: surgical_tools
```

**3. Events** (مهم جداً!):
```
☑️ Insert   ← تأكد أنه محدد (✓)
☑️ Update   ← تأكد أنه محدد (✓)
☐ Delete    ← اتركه فارغ
```

**4. Webhook Configuration:**
```
Type: HTTP Request
Method: POST
URL: https://little-mice-ask.loca.lt/api/notify/product-change
```

**5. HTTP Headers** (اضغط "+ Add header"):
```
Key: Content-Type
Value: application/json
```

**6. Timeout:**
```
5000  (أو اترك default)
```

**7. اضغط: Confirm** ✅

---

### 3️⃣ تحقق من Status

**بعد إنشاء Webhook:**

في قائمة Webhooks، يجب أن تشاهد:

```
Name                          Table            Status
surgical_tools_notifications  surgical_tools   🟢 Enabled
```

**Status يجب أن يكون:**
- ✅ 🟢 **Enabled** (أخضر)
- ❌ 🔴 **Disabled** (رمادي/أحمر)

**إذا كان Disabled:**
1. اضغط على الـ webhook
2. اضغط **Enable** أو **⋮ > Enable**

---

### 4️⃣ اختبار فوري

**في Supabase SQL Editor:**

```sql
INSERT INTO surgical_tools (tool_name, company)
VALUES ('Webhook Test ' || NOW()::text, 'Test Company');
```

**انتظر 2-3 ثواني**

---

### 5️⃣ فحص Logs

**اذهب إلى:**
Database > Webhooks > surgical_tools_notifications > **Logs**

**يجب أن تشاهد:**
```
Timestamp             Status  Response
2025-01-08 10:30:15   200     Success
```

**إذا شاهدت:**
- ✅ **Status: 200** → Webhook وصل بنجاح!
- ❌ **Status: 404** → URL خطأ
- ❌ **Status: 500** → خطأ في Server
- ❌ **لا توجد logs** → Webhook لم يُطلق (Events غير محددة أو Disabled)

---

## 🐛 Troubleshooting

### المشكلة 1: لا توجد Logs بعد INSERT

**السبب:** Events غير محددة!

**الحل:**
1. افتح Webhook
2. تحقق من أن **☑️ Insert** محدد
3. إذا لم يكن محدد، احذف webhook وأعد إنشاءه

---

### المشكلة 2: Status = Disabled

**الحل:**
1. اضغط على webhook
2. اضغط **Enable**

---

### المشكلة 3: Status 404 في Logs

**السبب:** URL خطأ

**الحل:** تأكد من URL:
```
✅ https://little-mice-ask.loca.lt/api/notify/product-change
❌ https://little-mice-ask.loca.lt/api/notify/product-changes (خطأ املائي)
❌ https://little-mice-ask.loca.lt (ناقص /api/notify/product-change)
```

---

### المشكلة 4: Status 500 في Logs

**السبب:** خطأ في notification server

**الحل:**
1. افحص Terminal حيث `npm start`
2. ابحث عن أخطاء
3. أرسلها لي

---

## 📸 Screenshot مطلوب

**أرسل لي screenshot من:**

### 1. Webhook Configuration:
```
Database > Webhooks > surgical_tools_notifications > Configuration
```

أريد أن أرى:
- Events (Insert/Update محددة؟)
- URL
- Status

### 2. Webhooks List:
```
Database > Webhooks
```

أريد أن أرى:
- اسم webhook
- Status (Enabled أو Disabled)

---

## 🎯 الخطوات المختصرة

إذا كنت متأكد من الإعدادات:

**1. احذف webhook القديم**
**2. أضف webhook جديد:**
   - Table: `surgical_tools`
   - Events: ✅ Insert, ✅ Update
   - URL: `https://little-mice-ask.loca.lt/api/notify/product-change`
   - Header: `Content-Type: application/json`
**3. اختبر:**
   ```sql
   INSERT INTO surgical_tools (tool_name, company)
   VALUES ('Test', 'Test');
   ```
**4. افحص Logs**

---

## 💡 ملاحظة مهمة

**Supabase Database Webhooks** موجودة في:
```
Supabase Dashboard
  └── Database (القائمة الجانبية)
      └── Webhooks (في الأعلى tabs)
```

**وليس:**
- ❌ Edge Functions > Webhooks
- ❌ Settings > Webhooks

---

**أخبرني: هل Webhook Status = Enabled أو Disabled؟** 🔍
