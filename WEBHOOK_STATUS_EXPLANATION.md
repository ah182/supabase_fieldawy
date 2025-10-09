# 📖 شرح: Webhook Status في Supabase

## ❓ ماذا يعني Status = Enabled؟

**Status** هو حالة الـ webhook في Supabase.

---

## 🟢 Enabled (مُفعّل)

**معناها:**
- ✅ Webhook **يعمل**
- ✅ عند إضافة/تحديث في الجدول، Supabase **سيُرسل** HTTP request
- ✅ Logs ستظهر

**الشكل:**
```
Name                Status
surgical_tools     🟢 Enabled
```

---

## 🔴 Disabled (مُعطّل)

**معناها:**
- ❌ Webhook **لا يعمل**
- ❌ عند إضافة/تحديث، Supabase **لن يُرسل** HTTP request
- ❌ Logs ستبقى فارغة
- ❌ لن تصل إشعارات

**الشكل:**
```
Name                Status
surgical_tools     🔴 Disabled
```

---

## 📍 كيف تجد Status؟

### الطريقة 1: في قائمة Webhooks

**الخطوات:**
1. Supabase Dashboard
2. **Database** (القائمة الجانبية)
3. **Webhooks** (tab في الأعلى)
4. ستشاهد جدول:

```
┌──────────────────────┬────────────────┬──────────┐
│ Name                 │ Table          │ Status   │
├──────────────────────┼────────────────┼──────────┤
│ surgical_tools_hook  │ surgical_tools │ Enabled  │ ✅
└──────────────────────┴────────────────┴──────────┘
```

أو:

```
┌──────────────────────┬────────────────┬──────────┐
│ Name                 │ Table          │ Status   │
├──────────────────────┼────────────────┼──────────┤
│ surgical_tools_hook  │ surgical_tools │ Disabled │ ❌
└──────────────────────┴────────────────┴──────────┘
```

---

### الطريقة 2: داخل Webhook

**الخطوات:**
1. اضغط على webhook من القائمة
2. ستشاهد صفحة التفاصيل
3. في الأعلى أو الجانب، ستشاهد:

```
Status: Enabled ✅
```

أو:

```
Status: Disabled ❌
```

---

## 🔄 كيف تُغيّر Status؟

### لتفعيل Webhook (Enable):

**الخطوة 1:** اضغط على webhook
**الخطوة 2:** ابحث عن زر **Enable** أو **⋮ > Enable**
**الخطوة 3:** اضغط عليه
**النتيجة:** Status سيصبح **Enabled** ✅

---

### لتعطيل Webhook (Disable):

**الخطوة 1:** اضغط على webhook
**الخطوة 2:** ابحث عن زر **Disable** أو **⋮ > Disable**
**الخطوة 3:** اضغط عليه
**النتيجة:** Status سيصبح **Disabled** ❌

---

## 🧪 كيف تتأكد؟

### Test 1: شاهد القائمة

```
Database > Webhooks

يجب أن تشاهد:
surgical_tools_notifications    surgical_tools    Enabled ✅
```

---

### Test 2: اختبر عملياً

**إذا Status = Enabled:**
```sql
INSERT INTO surgical_tools (tool_name, company) VALUES ('Test', 'Test');
```

**يجب أن:**
- ✅ Logs تظهر في Supabase
- ✅ Server يستقبل webhook
- ✅ إشعار يُرسل

---

**إذا Status = Disabled:**
```sql
INSERT INTO surgical_tools (tool_name, company) VALUES ('Test', 'Test');
```

**النتيجة:**
- ❌ لا شيء يحدث
- ❌ Logs فارغة
- ❌ Server لا يستقبل شيء

---

## 🎯 الخلاصة

| Status | معناها | النتيجة |
|--------|--------|---------|
| 🟢 **Enabled** | Webhook يعمل | إشعارات تُرسل ✅ |
| 🔴 **Disabled** | Webhook معطّل | لا شيء يحدث ❌ |

---

## 📸 مثال بالصور

### ✅ Enabled (صحيح):
```
╔══════════════════════════════════════════╗
║ Webhooks                                  ║
╠════════════════╦═══════════════╦═════════╣
║ Name           ║ Table         ║ Status  ║
╠════════════════╬═══════════════╬═════════╣
║ surgical_tools ║ surgical_tools║ 🟢Enabled║ ← هذا جيد!
╚════════════════╩═══════════════╩═════════╝
```

### ❌ Disabled (خطأ):
```
╔══════════════════════════════════════════╗
║ Webhooks                                  ║
╠════════════════╦═══════════════╦═════════╣
║ Name           ║ Table         ║ Status  ║
╠════════════════╬═══════════════╬═════════╣
║ surgical_tools ║ surgical_tools║🔴Disabled║ ← هذا السبب!
╚════════════════╩═══════════════╩═════════╝
```

---

**إذا شاهدت Disabled، فعّله فوراً!** 🚀
