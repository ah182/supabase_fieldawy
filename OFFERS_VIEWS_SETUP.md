# إعداد نظام المشاهدات للعروض

## 🔧 التغييرات المطبقة:

### 1. **تحديث نموذج البيانات:**
- ✅ إضافة حقل `views` إلى `OfferModel`
- ✅ تحديث `fromMap`, `toMap`, و `copyWith`

### 2. **تحديث قاعدة البيانات:**
- ✅ إضافة عمود `views` لجدول `offers`
- ✅ إنشاء دالة `increment_offer_views()`
- ✅ إضافة فهارس لتحسين الأداء

### 3. **تحديث الكود:**
- ✅ إضافة دعم `offers` في `product_card.dart`
- ✅ تحديث `offers_home_provider.dart` لاستخدام `offer_id`
- ✅ تحديث استعلامات قاعدة البيانات

## 📋 خطوات التطبيق:

### 1. **تشغيل ملف SQL في Supabase:**
```sql
-- تشغيل الملف في Supabase Dashboard > SQL Editor
\i supabase/migrations/add_views_to_offers.sql
```

أو نسخ محتويات الملف وتشغيلها مباشرة:
```sql
-- إضافة عمود المشاهدات لجدول الـ offers
ALTER TABLE offers ADD COLUMN IF NOT EXISTS views INTEGER DEFAULT 0;

-- إنشاء دالة لزيادة مشاهدات العرض
CREATE OR REPLACE FUNCTION increment_offer_views(p_offer_id TEXT)
RETURNS VOID AS $$
BEGIN
    -- تسجيل المحاولة للتتبع
    RAISE NOTICE 'Incrementing views for offer: %', p_offer_id;
    
    -- التحقق من وجود العرض
    IF EXISTS (SELECT 1 FROM offers WHERE id = p_offer_id) THEN
        UPDATE offers 
        SET views = COALESCE(views, 0) + 1
        WHERE id = p_offer_id;
        
        RAISE NOTICE 'Views incremented successfully for offer: %', p_offer_id;
    ELSE
        RAISE NOTICE 'Offer not found: %', p_offer_id;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error incrementing offer views: % %', SQLERRM, SQLSTATE;
END;
$$ LANGUAGE plpgsql;

-- تحديث جميع العروض الموجودة لتبدأ بـ 0 مشاهدات
UPDATE offers SET views = 0 WHERE views IS NULL;

-- إضافة فهرس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_offers_views ON offers(views);
CREATE INDEX IF NOT EXISTS idx_offers_views_created_at ON offers(views, created_at);
```

### 2. **إعادة تشغيل التطبيق:**
```bash
flutter clean
flutter pub get
# ثم تشغيل التطبيق
```

## 🎯 النتيجة المتوقعة:

بعد تطبيق التغييرات:
- ✅ **عداد المشاهدات يظهر** في جميع كارت العروض
- ✅ **المشاهدات تزيد تلقائياً** عند ظهور العرض
- ✅ **البيانات تحفظ** في قاعدة البيانات
- ✅ **يبدأ من 0** ويزيد تدريجياً

## 🔍 لفحص النتائج:

1. **في Supabase Dashboard:**
```sql
-- فحص عمود المشاهدات
SELECT id, views FROM offers LIMIT 10;

-- اختبار الدالة
SELECT increment_offer_views('offer_id_here');
```

2. **في التطبيق:**
- افتح تاب "Offers"
- لاحظ عدادات المشاهدات
- اسحب الشاشة لأسفل وأعلى لرؤية زيادة المشاهدات

## ❗ في حالة عدم عمل المشاهدات:

1. **تأكد من تشغيل SQL:**
```sql
-- فحص وجود العمود
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'offers' AND column_name = 'views';

-- فحص وجود الدالة
SELECT routine_name FROM information_schema.routines 
WHERE routine_name = 'increment_offer_views';
```

2. **فحص الـ logs في التطبيق:**
- ابحث عن رسائل "Incrementing views for offer"
- تأكد من أن `offer_id` صحيح

3. **إعادة تشغيل التطبيق** تماماً

## 🎉 الآن جميع التابات تدعم المشاهدات:
- ✅ Home
- ✅ Price Action  
- ✅ Expire Soon
- ✅ Surgical Tools
- ✅ **Offers** 🆕