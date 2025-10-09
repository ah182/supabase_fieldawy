# 🔧 إصلاح: الإشعارات لا تظهر

## ❌ المشكلة

Triggers تعمل بدون أخطاء، لكن **لا توجد إشعارات** عند:
- إضافة منتج
- تحديث سعر
- إضافة عرض
- إضافة أداة جراحية

---

## 💡 السبب

الـ trigger يستخدم `pg_notify()` الذي يُرسل notification **داخل PostgreSQL فقط**!

```sql
PERFORM pg_notify('product_notification', ...);
-- ✅ يُرسل notification
-- ❌ لكن لا أحد يستمع!
```

**المشكلة:** `notification_webhook_server.js` **لا يستمع** لـ PostgreSQL notifications!

---

## ✅ الحل: استخدام Supabase Database Webhooks

### الطريقة 1: Database Webhooks (موصى بها)

#### الخطوة 1: تشغيل Notification Server

```bash
cd D:\fieldawy_store
npm start
```

**يجب أن تشاهد:**
```
🚀 Notification webhook server is running on port 3000
📡 Endpoint: http://localhost:3000/api/notify/product-change
```

---

#### الخطوة 2: استخدام ngrok لتعريض السيرفر المحلي

```bash
# في terminal جديد
ngrok http 3000
```

**ستحصل على URL مثل:**
```
https://abc123.ngrok.io
```

---

#### الخطوة 3: إضافة Webhook في Supabase

1. افتح **Supabase Dashboard**
2. اذهب إلى **Database** > **Webhooks**
3. اضغط **Create a new hook**
4. املأ البيانات:
   - **Name:** Product Notifications
   - **Table:** `products` (سنضيف باقي الجداول لاحقاً)
   - **Events:** ✅ Insert, ✅ Update
   - **Type:** HTTP Request
   - **Method:** POST
   - **URL:** `https://abc123.ngrok.io/api/notify/product-change`
   - **HTTP Headers:** 
     ```
     Content-Type: application/json
     ```

5. كرر لباقي الجداول:
   - distributor_products
   - surgical_tools
   - distributor_surgical_tools
   - offers

---

### الطريقة 2: تعديل Trigger لإرسال مباشر (بدون webhook)

استخدام `http extension` في PostgreSQL:

```sql
-- تفعيل HTTP extension
CREATE EXTENSION IF NOT EXISTS http;

-- تعديل trigger function
CREATE OR REPLACE FUNCTION notify_product_change()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url text := 'https://abc123.ngrok.io/api/notify/product-change';
  response text;
BEGIN
  -- تحديد product_name و tab_name (نفس الكود السابق)
  -- ...
  
  -- إرسال HTTP request مباشرة
  SELECT content INTO response
  FROM http_post(
    webhook_url,
    json_build_object(
      'operation', TG_OP,
      'table', TG_TABLE_NAME,
      'product_name', product_name,
      'tab_name', tab_name
    )::text,
    'application/json'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### الطريقة 3: استخدام Supabase Edge Function (الأفضل للـ Production)

#### إنشاء Edge Function:

```bash
# تثبيت Supabase CLI
npm install -g supabase

# إنشاء Edge Function
supabase functions new send-product-notification
```

#### محتوى Function:

```typescript
// supabase/functions/send-product-notification/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { table, operation, product_name, tab_name } = await req.json()
  
  // الحصول على جميع tokens
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )
  
  const { data: tokens } = await supabase
    .from('user_tokens')
    .select('token')
  
  // إرسال FCM notifications
  const fcmUrl = 'https://fcm.googleapis.com/v1/projects/YOUR_PROJECT/messages:send'
  
  for (const { token } of tokens) {
    await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('FCM_SERVER_KEY')}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        message: {
          token: token,
          data: {
            title: `${operation === 'INSERT' ? 'تم إضافة' : 'تم تحديث'} ${product_name}`,
            body: `في ${tab_name}`,
            screen: tab_name
          }
        }
      })
    })
  }
  
  return new Response('OK')
})
```

---

## 🧪 اختبار

### Test 1: التحقق من استقبال Webhook

في terminal حيث يعمل notification server، يجب أن تشاهد:

```
📩 تلقي webhook من Supabase
   Operation: INSERT
   Table: products
   Product Name: Panadol
   Tab Name: home
✅ تم إرسال الإشعار بنجاح!
```

---

### Test 2: التحقق من FCM Token

```sql
-- في Supabase SQL Editor
SELECT COUNT(*) FROM user_tokens;
```

إذا كانت النتيجة `0`:
- ❌ لا توجد tokens محفوظة
- ✅ سجّل دخول في التطبيق لحفظ token

---

### Test 3: إضافة منتج

```sql
INSERT INTO products (name, company) VALUES ('Test Product', 'Test Co');
```

**يجب أن يحدث:**
1. ✅ Webhook يُرسل للـ server
2. ✅ Server يطبع log في console
3. ✅ FCM notification يُرسل
4. ✅ إشعار يظهر على الجهاز

---

## 🐛 Troubleshooting

### مشكلة: Server لا يستقبل requests

**التحقق:**
```bash
# في terminal
curl -X POST http://localhost:3000/api/notify/product-change \
  -H "Content-Type: application/json" \
  -d '{"operation":"INSERT","table":"products","product_name":"Test","tab_name":"home"}'
```

**النتيجة المتوقعة:**
```json
{"success":true,"message":"Notification sent"}
```

---

### مشكلة: ngrok لا يعمل

**البديل:** استخدام Supabase Edge Functions أو deploy السيرفر على Heroku/Railway.

---

### مشكلة: Webhook لا يُرسل

**التحقق:**
```sql
-- عرض logs
SELECT * FROM supabase_functions.http_request_queue 
ORDER BY created_at DESC 
LIMIT 10;
```

---

## 📊 الحل الموصى به

### للتطوير (Development):
✅ **ngrok + notification_webhook_server.js**
- سريع
- سهل الاختبار
- لا يحتاج deployment

### للإنتاج (Production):
✅ **Supabase Edge Functions**
- مستضافة على Supabase
- تعمل 24/7
- آمنة
- مجانية (ضمن حدود Supabase)

---

## 🚀 الخطوات السريعة

### الآن (للاختبار):

1. **شغّل notification server:**
   ```bash
   cd D:\fieldawy_store
   npm start
   ```

2. **شغّل ngrok:**
   ```bash
   ngrok http 3000
   ```

3. **أضف Webhook في Supabase** للجداول:
   - products
   - distributor_products
   - surgical_tools
   - distributor_surgical_tools
   - offers

4. **اختبر بإضافة منتج!**

---

## 💡 ملاحظة مهمة

**pg_notify لن يعمل** مع webhook server المحلي!

الحلول:
1. ✅ استخدام Supabase Database Webhooks
2. ✅ استخدام Supabase Edge Functions
3. ✅ أو listener في Node.js لـ PostgreSQL notifications (معقد)

**الأسهل:** Supabase Database Webhooks + ngrok للتطوير!
