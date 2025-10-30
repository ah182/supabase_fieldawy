-- ==========================================
-- الحل الأبسط: Function تعمل مع جميع الأنواع
-- ==========================================

-- حذف Function القديمة
DROP FUNCTION IF EXISTS increment_product_views(TEXT);

-- إنشاء Function جديدة محسنة
CREATE OR REPLACE FUNCTION increment_product_views(p_product_id TEXT)
RETURNS void 
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
BEGIN
    -- جرب UPDATE مباشرة (يعمل مع integer و uuid)
    UPDATE distributor_products 
    SET views = COALESCE(views, 0) + 1 
    WHERE CAST(id AS TEXT) = p_product_id;
    
    -- إذا لم يجد أي صف، لا تفعل شيئاً
    -- (بدون رفع خطأ)
END;
$$;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_product_views(TEXT) TO anon;

-- اختبار
-- SELECT increment_product_views('649');
-- SELECT id, name, views FROM distributor_products WHERE CAST(id AS TEXT) = '649';

-- ==========================================
-- ✅ تم! شغل هذا SQL أولاً ثم اختبر
-- ==========================================
