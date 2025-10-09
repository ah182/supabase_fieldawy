# 🚀 نشر نظام الإشعارات للإنتاج

## ✅ النظام يعمل الآن!

لكن localtunnel للتطوير فقط.

للإنتاج، تحتاج حل دائم.

---

## 🎯 أفضل 3 حلول

### الحل 1: Supabase Edge Functions ⭐ (موصى به)

**المميزات:**
- ✅ مجاني (ضمن حدود Supabase)
- ✅ مستضاف على Supabase نفسه
- ✅ URL ثابت
- ✅ يعمل 24/7
- ✅ لا يحتاج server خارجي

**العيوب:**
- يحتاج إعداد بسيط (Deno TypeScript)

---

### الحل 2: Railway / Render (سهل)

**المميزات:**
- ✅ سهل جداً في النشر
- ✅ مجاني للبداية
- ✅ URL ثابت
- ✅ يعمل 24/7
- ✅ يدعم Node.js مباشرة

**العيوب:**
- قد تحتاج بطاقة ائتمان للتحقق

---

### الحل 3: PythonAnywhere / Heroku

**المميزات:**
- ✅ مجاني
- ✅ URL ثابت

**العيوب:**
- Heroku يحتاج بطاقة ائتمان
- PythonAnywhere أبطأ قليلاً

---

## 🏆 الحل الموصى به: Supabase Edge Functions

### لماذا؟
- كل شيء في مكان واحد (Supabase)
- لا تحتاج خدمات خارجية
- مجاني تماماً
- سريع جداً

---

## 📝 خطوات النشر على Supabase Edge Functions

### 1️⃣ تثبيت Supabase CLI

```bash
npm install -g supabase
```

---

### 2️⃣ تسجيل الدخول

```bash
supabase login
```

---

### 3️⃣ ربط المشروع

```bash
cd D:\fieldawy_store
supabase link --project-ref your-project-ref
```

**للحصول على project-ref:**
- افتح Supabase Dashboard
- Settings > General
- انسخ Reference ID

---

### 4️⃣ إنشاء Edge Function

```bash
supabase functions new send-product-notification
```

---

### 5️⃣ محتوى Function

**ملف:** `supabase/functions/send-product-notification/index.ts`

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  try {
    const payload = await req.json()
    
    // استخراج البيانات
    const operation = payload.type || payload.operation
    const table = payload.table
    const record = payload.record || payload.new || {}
    
    // تحديد اسم المنتج
    let product_name = "منتج"
    if (table === "surgical_tools") {
      product_name = record.tool_name || "أداة جراحية"
    } else if (table === "distributor_surgical_tools") {
      product_name = record.description || "أداة جراحية"
    } else if (table === "products") {
      product_name = record.name || "منتج"
    } else if (table === "offers") {
      product_name = record.description || "عرض"
    }
    
    // تحديد tab
    let tab_name = "home"
    if (table === "surgical_tools" || table === "distributor_surgical_tools") {
      tab_name = "surgical"
    } else if (table === "offers") {
      tab_name = "offers"
    }
    
    // إرسال FCM notification
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${Deno.env.get('FCM_PROJECT_ID')}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${Deno.env.get('FCM_ACCESS_TOKEN')}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          message: {
            topic: 'all_users',
            data: {
              title: `${operation === 'INSERT' ? 'تم إضافة' : 'تم تحديث'} منتج جديد! 🎉`,
              body: `${product_name} في ${tab_name}`,
              type: 'product_update',
              screen: tab_name
            },
            android: {
              priority: 'high'
            }
          }
        })
      }
    )
    
    return new Response(
      JSON.stringify({ success: true }),
      { headers: { "Content-Type": "application/json" } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    )
  }
})
```

---

### 6️⃣ رفع Function

```bash
supabase functions deploy send-product-notification
```

---

### 7️⃣ ضبط Environment Variables

```bash
supabase secrets set FCM_PROJECT_ID=fieldawy-store-app
supabase secrets set FCM_ACCESS_TOKEN=your-access-token
```

---

### 8️⃣ تحديث Webhooks في Supabase

**URL الجديد:**
```
https://your-project-ref.supabase.co/functions/v1/send-product-notification
```

---

## 🚀 الحل 2: Railway (الأسهل!)

### 1️⃣ اذهب إلى railway.app

### 2️⃣ سجّل دخول بـ GitHub

### 3️⃣ اضغط "New Project"

### 4️⃣ اختر "Deploy from GitHub repo"

### 5️⃣ اختر repository الخاص بك

### 6️⃣ Railway سينشر تلقائياً!

### 7️⃣ احصل على URL:

```
https://your-app.railway.app
```

### 8️⃣ حدّث Webhooks:

```
https://your-app.railway.app/api/notify/product-change
```

✅ **انتهى! يعمل للأبد!**

---

## 💡 الحل المؤقت (للتطوير):

إذا كنت تريد الاستمرار مع localtunnel:

### استخدم ngrok بـ domain ثابت:

```bash
# سجّل حساب مجاني في ngrok.com
# ثم:
ngrok config add-authtoken YOUR_TOKEN
ngrok http 3000 --domain=your-custom-domain.ngrok-free.app
```

**المميزات:**
- ✅ Domain ثابت (لا يتغير)
- ✅ لا تحتاج تحديث webhooks

---

## 📊 مقارنة الحلول

| الحل | سهولة | تكلفة | URL ثابت | يعمل 24/7 |
|------|-------|-------|----------|-----------|
| **Supabase Edge Functions** | متوسط | مجاني | ✅ | ✅ |
| **Railway** | سهل جداً | مجاني* | ✅ | ✅ |
| **ngrok مدفوع** | سهل | $8/شهر | ✅ | ❌ |
| **localtunnel** | سهل | مجاني | ❌ | ❌ |

*Railway: 500 ساعة/شهر مجاناً = كافية للتطبيق

---

## 🎯 توصيتي:

### للبداية (الآن):
✅ استخدم **Railway** - الأسهل والأسرع!

### للمستقبل:
✅ انتقل لـ **Supabase Edge Functions** - كل شيء في مكان واحد

---

## 🚀 خطوات النشر السريع على Railway

1. اذهب إلى: https://railway.app
2. سجّل دخول بـ GitHub
3. "New Project" > "Deploy from GitHub"
4. اختر repository
5. انتظر 2-3 دقائق
6. احصل على URL
7. حدّث webhooks في Supabase
8. ✅ **انتهى!**

---

## 📁 ملفات مطلوبة للنشر

تأكد من وجود:
- ✅ `package.json` (موجود)
- ✅ `notification_webhook_server.js` (موجود)
- ✅ `fieldawy-store-app-66c0ffe5a54f.json` (موجود)

**Railway سيكتشفهم تلقائياً!**

---

**هل تريد أن أساعدك في النشر على Railway الآن؟** 🚀
