-- إصلاح سريع لإضافة المشاهدات للعروض
-- تشغيل هذا الكود في Supabase Dashboard > SQL Editor

-- 1. إضافة عمود المشاهدات إذا لم يكن موجوداً
ALTER TABLE offers ADD COLUMN IF NOT EXISTS views INTEGER DEFAULT 0;

-- 2. تحديث جميع العروض الموجودة لتبدأ بـ 0
UPDATE offers SET views = 0 WHERE views IS NULL;

-- 3. إنشاء دالة بسيطة لزيادة المشاهدات
CREATE OR REPLACE FUNCTION increment_offer_views(p_offer_id TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE offers 
    SET views = COALESCE(views, 0) + 1
    WHERE id = p_offer_id;
END;
$$ LANGUAGE plpgsql;

-- 4. اختبار الدالة مع أول عرض موجود
DO $$
DECLARE
    test_offer_id TEXT;
    views_before INTEGER;
    views_after INTEGER;
BEGIN
    -- البحث عن عرض موجود
    SELECT id INTO test_offer_id FROM offers LIMIT 1;
    
    IF test_offer_id IS NOT NULL THEN
        -- قراءة المشاهدات قبل التحديث
        SELECT views INTO views_before FROM offers WHERE id = test_offer_id;
        
        -- تشغيل الدالة
        PERFORM increment_offer_views(test_offer_id);
        
        -- قراءة المشاهدات بعد التحديث
        SELECT views INTO views_after FROM offers WHERE id = test_offer_id;
        
        RAISE NOTICE 'Test Results: Offer ID: %, Views Before: %, Views After: %', 
                     test_offer_id, views_before, views_after;
    ELSE
        RAISE NOTICE 'No offers found for testing';
    END IF;
END $$;

-- 5. إضافة فهرس
CREATE INDEX IF NOT EXISTS idx_offers_views ON offers(views);

-- 6. فحص النتائج
SELECT 'Setup completed. Current offers with views:' AS status;
SELECT id, views, created_at FROM offers ORDER BY created_at DESC LIMIT 5;