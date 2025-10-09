-- ============================================
-- حذف Views المكررة
-- ============================================

-- حذف View للمنتجات قرب الانتهاء
DROP VIEW IF EXISTS distributor_products_expiring_soon;

-- حذف View للمنتجات بتغيير السعر
DROP VIEW IF EXISTS distributor_products_price_changes;

-- ملاحظة: الـ Functions ستبقى وهي:
-- - get_expiring_products(int)
-- - get_price_changed_products(int)

-- هذه Functions تجمع البيانات من الجدولين معاً وهي الأفضل للاستخدام

COMMENT ON FUNCTION get_expiring_products(int) IS 
'الحصول على جميع المنتجات قرب الانتهاء من distributor_products + distributor_ocr_products';

COMMENT ON FUNCTION get_price_changed_products(int) IS 
'الحصول على جميع المنتجات بتغيير سعر من distributor_products + distributor_ocr_products';

-- ============================================
-- اختبار Functions بعد حذف Views
-- ============================================

-- للاختبار:
-- SELECT * FROM get_expiring_products(60);
-- SELECT * FROM get_price_changed_products(30);
