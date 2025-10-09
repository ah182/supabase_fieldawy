-- ============================================
-- (اختياري) حذف Views المكررة
-- ============================================

-- إذا كنت تفضل استخدام Functions فقط، يمكنك حذف Views:

DROP VIEW IF EXISTS distributor_products_expiring_soon;
DROP VIEW IF EXISTS distributor_products_price_changes;

-- الآن استخدم Functions فقط:
-- SELECT * FROM get_expiring_products(60);
-- SELECT * FROM get_price_changed_products(30);

-- ملاحظة: Views مفيدة للـ debugging، لذا يُفضل إبقائها
