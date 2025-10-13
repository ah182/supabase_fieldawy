# 🔧 إصلاح Supabase Webhooks

## المشكلة الحالية

الـ webhooks موجودة لكن:
- ❌ بتشتغل على `UPDATE` و `INSERT` معاً
- ✅ احنا عايزين **INSERT فقط**

---

## ✅ الحل السريع

### في Supabase Dashboard:

#### 1. عدل webhook: `reviewrequests`
1. اذهب لـ **Database** → **Webhooks**
2. اضغط على `reviewrequests`
3. في **Events**:
   - ✅ اختار **Insert** فقط
   - ❌ ألغِ **Update**
4. احفظ

#### 2. عدل webhook: `productreviews`
1. اضغط على `productreviews`
2. في **Events**:
   - ✅ اختار **Insert** فقط
   - ❌ ألغِ **Update**
3. احفظ

---

## 🧪 اختبار Worker

قبل ما تجرب من التطبيق، اختبر الـ Worker يدوياً:

```bash
cd D:\fieldawy_store
node test_webhook_manual.js
```

**المتوقع:**
```
✅ Response: 200
📦 Body: Notification sent
✅ Test PASSED - Worker is working!
```

---

## 🔍 التحقق من الـ Payload

المشكلة المحتملة إن Supabase بيبعت payload مختلف عن اللي بنتوقعه.

### Payload من Supabase Webhooks:

```json
{
  "type": "INSERT",
  "table": "product_reviews",
  "record": {
    "id": "uuid",
    "review_request_id": "uuid",
    "product_id": "123",
    "product_type": "product",
    "user_id": "uuid",
    "user_name": "الاسم",
    "rating": 5,
    "comment": "التعليق",
    "created_at": "2025-01-25T..."
  },
  "schema": "public",
  "old_record": null
}
```

**المشكلة:** مفيش `product_name` و `reviewer_name` في الـ record!

---

## 🔧 الحل: تحديث Cloudflare Worker

الـ Worker محتاج يجيب البيانات الناقصة من Supabase!

في `cloudflare-webhook/src/index.js`:

```javascript
// Handle product reviews (comments)
if (table === 'product_reviews') {
  if (operation !== 'INSERT') {
    return new Response('Skipped', { status: 200, headers: corsHeaders });
  }
  
  // ⚠️ المشكلة: record مفيهوش product_name و reviewer_name
  // الحل: جيبهم من Supabase
  
  let productName = 'منتج';
  let reviewerName = 'مستخدم';
  
  // جلب بيانات إضافية من Supabase
  if (env.SUPABASE_URL && env.SUPABASE_SERVICE_KEY) {
    try {
      // جلب اسم المنتج من review_requests
      const reqResponse = await fetch(
        `${env.SUPABASE_URL}/rest/v1/review_requests?id=eq.${record.review_request_id}&select=product_name`,
        {
          headers: {
            'apikey': env.SUPABASE_SERVICE_KEY,
            'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
          }
        }
      );
      const reqData = await reqResponse.json();
      if (reqData && reqData[0]) {
        productName = reqData[0].product_name;
      }
      
      // جلب اسم المراجع من users
      const userResponse = await fetch(
        `${env.SUPABASE_URL}/rest/v1/users?id=eq.${record.user_id}&select=display_name,email`,
        {
          headers: {
            'apikey': env.SUPABASE_SERVICE_KEY,
            'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
          }
        }
      );
      const userData = await userResponse.json();
      if (userData && userData[0]) {
        reviewerName = userData[0].display_name || userData[0].email;
      }
    } catch (err) {
      console.error('Error fetching data:', err);
    }
  }
  
  const rating = record.rating || 0;
  const comment = record.comment || '';
  
  const title = `⭐ تم تقييم ${productName}`;
  const body = `${reviewerName} (${rating}⭐): ${comment}`;
  
  return await sendFCMNotification(env, title, body, 'reviews', {
    type: 'new_product_review',
    review_id: record.id,
    product_id: record.product_id,
    rating: rating,
  });
}
```

---

## ⚡ الحل الأسرع (بدون تعديل Worker)

استخدم **SQL Triggers بدلاً من Database Webhooks**:

### 1. احذف الـ webhooks من Dashboard

### 2. في Supabase SQL Editor:

```sql
-- تفعيل pg_net
CREATE EXTENSION IF NOT EXISTS pg_net;

-- نفذ الملف:
-- FIX_hardcode_webhook_url.sql
-- (بعد وضع الـ URL الصحيح فيه)
```

**مزايا SQL Triggers:**
- ✅ الـ payload يحتوي على كل البيانات المطلوبة
- ✅ يجيب product_name و reviewer_name تلقائياً
- ✅ أسرع في الاستجابة

---

## 📊 المقارنة

| الطريقة | السهولة | البيانات الكاملة | السرعة |
|---------|----------|------------------|---------|
| **Database Webhooks** | ⭐⭐⭐⭐⭐ | ❌ (يحتاج fetch إضافي) | ⭐⭐⭐ |
| **SQL Triggers** | ⭐⭐⭐ | ✅ (كل شيء جاهز) | ⭐⭐⭐⭐⭐ |

---

## 🎯 التوصية النهائية

**استخدم SQL Triggers** لأنها:
1. ✅ أسرع
2. ✅ البيانات كاملة
3. ✅ لا تحتاج fetch إضافي

**الخطوات:**
1. احذف الـ Database Webhooks من Dashboard
2. نفذ `FIX_hardcode_webhook_url.sql` (مع وضع الـ URL)
3. جاهز! 🎉

---

## 🆘 إذا اخترت Database Webhooks

**يجب تعديل الـ Worker** لجلب البيانات الناقصة من Supabase.

هل تريد الكود الكامل لهذا الحل؟
