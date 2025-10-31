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
        
        -- إضافة سجل في جدول الإحصائيات إذا كان موجوداً
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'analytics_views') THEN
            INSERT INTO analytics_views (
                entity_type,
                entity_id,
                viewed_at
            ) VALUES (
                'offer',
                p_offer_id,
                NOW()
            );
        END IF;
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

-- اختبار الدالة (يمكن حذف هذا الجزء بعد التأكد من عملها)
DO $$
DECLARE
    test_offer_id TEXT;
BEGIN
    -- البحث عن عرض موجود للاختبار
    SELECT id INTO test_offer_id FROM offers LIMIT 1;
    
    IF test_offer_id IS NOT NULL THEN
        RAISE NOTICE 'Testing increment_offer_views with offer: %', test_offer_id;
        PERFORM increment_offer_views(test_offer_id);
        RAISE NOTICE 'Test completed successfully';
    ELSE
        RAISE NOTICE 'No offers found for testing';
    END IF;
END $$;