# Image Migration: Cloudinary to Supabase Storage

هذا السكريبت ينقل الصور من Cloudinary إلى Supabase Storage.

## الإعداد

1. **تثبيت الـ dependencies:**
   ```bash
   npm install
   ```

2. **إنشاء ملف `.env`:**
   ```bash
   cp .env.example .env
   ```

3. **تعديل `.env` بالبيانات الصحيحة:**
   - `SUPABASE_URL`: رابط مشروع Supabase
   - `SUPABASE_SERVICE_KEY`: مفتاح الـ service role (من Project Settings > API)

## التشغيل

### اختبار أولاً (5 صور فقط):
```bash
npm run migrate:test
```

### معاينة بدون تغييرات (Dry Run):
```bash
npm run migrate:dry-run
```

### التشغيل الكامل:
```bash
npm run migrate
```

## ملاحظات مهمة

- ⚠️ استخدم **Service Role Key** وليس الـ anon key
- ⚠️ تأكد من أن الـ bucket موجود ومفعّل كـ public
- ⚠️ اختبر أولاً قبل التشغيل الكامل!
