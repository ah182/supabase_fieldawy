# تفعيل Firebase Cloud Messaging API (Legacy)

## الطريقة الأسهل والأسرع! ⚡

بدلاً من التعقيدات، سنفعل Legacy API ونحصل على Server Key مباشرة.

---

## الخطوات (5 دقائق):

### 1️⃣ افتح Firebase Console

```
https://console.firebase.google.com/project/fieldawy-store-app/settings/cloudmessaging
```

### 2️⃣ في صفحة Cloud Messaging

ستجد أحد الأمور التالية:

#### **السيناريو A:** Legacy API موجود بالفعل ✅
```
Cloud Messaging API (Legacy)
━━━━━━━━━━━━━━━━━━━━━━━━
Server key: AAAA....
Sender ID: 665551059689
```

**➡️ انسخ Server key مباشرة!**

---

#### **السيناريو B:** Legacy API معطل ⚙️

ستجد:
```
Cloud Messaging API (Legacy)
This API is disabled. Click the ⋮ menu to enable it.
```

**الحل:**
1. اضغط على **⋮** (ثلاث نقاط) بجانب "Cloud Messaging API (Legacy)"
2. اختر **Enable Cloud Messaging API (Legacy)**
3. انتظر 30 ثانية
4. ✅ **ظهر Server Key!**

---

### 3️⃣ إذا لم تجد قسم Legacy API نهائياً

**الحل البديل:**

1. في نفس صفحة Cloud Messaging، اضغط على زر:
   ```
   ⋮ (ثلاث نقاط في الأعلى)
   → Manage API in Google Cloud Console
   ```

2. سيفتح Google Cloud Console

3. ابحث عن **Cloud Messaging API**

4. اضغط **Enable** إذا كان معطل

5. ارجع لـ Firebase Console → Cloud Messaging

6. ✅ ستجد Server Key ظهر!

---

### 4️⃣ إضافة Server Key في Supabase

بعد الحصول على Server Key (يبدأ بـ `AAAA...`):

```bash
cd D:\fieldawy_store

# إضافة Server Key
npx supabase secrets set FIREBASE_SERVER_KEY=AAAA...
```

---

### 5️⃣ نشر Edge Function المبسط

سأعطيك نسخة مبسطة تستخدم Legacy API مباشرة:

```bash
npx supabase functions deploy send-custom-notification
```

---

## لماذا Legacy API أفضل؟

| Legacy API | HTTP v1 API |
|------------|-------------|
| ✅ مفتاح واحد فقط | ❌ يحتاج Service Account + JWT |
| ✅ Batch requests (500/req) | ❌ طلب واحد لكل token |
| ✅ سهل جداً | ❌ معقد |
| ✅ يعمل فوراً | ❌ يحتاج setup |

---

## الخلاصة

1. افتح: https://console.firebase.google.com/project/fieldawy-store-app/settings/cloudmessaging
2. فعّل Cloud Messaging API (Legacy) إذا كان معطل
3. انسخ Server Key
4. شغّل: `npx supabase secrets set FIREBASE_SERVER_KEY=YOUR_KEY`
5. نشر: `npx supabase functions deploy send-custom-notification`

**✅ خلاص! بعدها الإشعارات ستعمل!**

---

## إذا واجهتك مشاكل

**ارجع للـ Firebase Console وصور لي:**
1. صفحة Cloud Messaging كاملة
2. وأنا سأوضح لك بالضبط فين Server Key

🚀
