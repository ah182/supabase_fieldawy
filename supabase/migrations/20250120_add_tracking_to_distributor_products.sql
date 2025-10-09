-- ============================================
-- إضافة تتبع السعر وتاريخ الانتهاء لجدول distributor_products
-- ============================================

-- 1️⃣ إضافة أعمدة جديدة

-- تاريخ انتهاء الصلاحية
ALTER TABLE distributor_products 
ADD COLUMN IF NOT EXISTS expiration_date timestamp with time zone;

-- السعر القديم (لتتبع التغييرات)
ALTER TABLE distributor_products 
ADD COLUMN IF NOT EXISTS old_price numeric;

-- تاريخ آخر تحديث للسعر
ALTER TABLE distributor_products 
ADD COLUMN IF NOT EXISTS price_updated_at timestamp with time zone;

-- 2️⃣ إضافة Indexes للأداء

-- Index على expiration_date للمنتجات قرب الانتهاء
CREATE INDEX IF NOT EXISTS idx_distributor_products_expiration 
ON distributor_products(expiration_date) 
WHERE expiration_date IS NOT NULL;

-- Index على price_updated_at
CREATE INDEX IF NOT EXISTS idx_distributor_products_price_updated 
ON distributor_products(price_updated_at DESC) 
WHERE price_updated_at IS NOT NULL;

-- 3️⃣ دالة لتحديث old_price تلقائياً عند تغيير السعر

CREATE OR REPLACE FUNCTION update_distributor_products_price_tracking()
RETURNS TRIGGER AS $$
BEGIN
  -- إذا تغير السعر
  IF TG_OP = 'UPDATE' AND OLD.price IS DISTINCT FROM NEW.price THEN
    NEW.old_price := OLD.price;
    NEW.price_updated_at := NOW();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4️⃣ إنشاء Trigger لتتبع تغيير السعر

DROP TRIGGER IF EXISTS trigger_track_price_change ON distributor_products;
CREATE TRIGGER trigger_track_price_change
BEFORE UPDATE ON distributor_products
FOR EACH ROW
EXECUTE FUNCTION update_distributor_products_price_tracking();

-- ملاحظة: تم حذف Views (distributor_products_expiring_soon & distributor_products_price_changes)
-- استخدم Functions بدلاً منها:
-- - get_expiring_products(int)
-- - get_price_changed_products(int)

-- 5️⃣ دالة للحصول على المنتجات قرب الانتهاء

CREATE OR REPLACE FUNCTION get_expiring_products(days_threshold int DEFAULT 60)
RETURNS TABLE (
  product_id uuid,
  product_name text,
  company text,
  package text,
  price numeric,
  expiration_date timestamp with time zone,
  days_until_expiry numeric,
  source text
) AS $$
BEGIN
  RETURN QUERY
  -- من distributor_ocr_products
  SELECT 
    docp.ocr_product_id as product_id,
    ocp.product_name,
    ocp.product_company as company,
    ocp.package,
    docp.price,
    docp.expiration_date,
    EXTRACT(DAY FROM (docp.expiration_date - NOW())) as days_until_expiry,
    'ocr' as source
  FROM distributor_ocr_products docp
  JOIN ocr_products ocp ON docp.ocr_product_id = ocp.id
  WHERE docp.expiration_date IS NOT NULL
    AND docp.expiration_date > NOW()
    AND docp.expiration_date <= (NOW() + INTERVAL '1 day' * days_threshold)
  
  UNION ALL
  
  -- من distributor_products
  SELECT 
    dp.product_id,
    p.name as product_name,
    p.company,
    dp.package,
    dp.price,
    dp.expiration_date,
    EXTRACT(DAY FROM (dp.expiration_date - NOW())) as days_until_expiry,
    'regular' as source
  FROM distributor_products dp
  JOIN products p ON dp.product_id = p.id
  WHERE dp.expiration_date IS NOT NULL
    AND dp.expiration_date > NOW()
    AND dp.expiration_date <= (NOW() + INTERVAL '1 day' * days_threshold)
  
  ORDER BY expiration_date ASC;
END;
$$ LANGUAGE plpgsql;

-- 6️⃣ دالة للحصول على المنتجات بتغيير السعر

CREATE OR REPLACE FUNCTION get_price_changed_products(days_ago int DEFAULT 30)
RETURNS TABLE (
  product_id uuid,
  product_name text,
  company text,
  package text,
  old_price numeric,
  new_price numeric,
  price_difference numeric,
  price_change_percentage numeric,
  updated_at timestamp with time zone,
  source text
) AS $$
BEGIN
  RETURN QUERY
  -- من distributor_ocr_products
  SELECT 
    docp.ocr_product_id as product_id,
    ocp.product_name,
    ocp.product_company as company,
    ocp.package,
    docp.old_price,
    docp.price as new_price,
    docp.price - docp.old_price as price_difference,
    ROUND(((docp.price - docp.old_price) / docp.old_price * 100)::numeric, 2) as price_change_percentage,
    docp.price_updated_at as updated_at,
    'ocr' as source
  FROM distributor_ocr_products docp
  JOIN ocr_products ocp ON docp.ocr_product_id = ocp.id
  WHERE docp.old_price IS NOT NULL
    AND docp.old_price != docp.price
    AND docp.price_updated_at >= (NOW() - INTERVAL '1 day' * days_ago)
  
  UNION ALL
  
  -- من distributor_products
  SELECT 
    dp.product_id,
    p.name as product_name,
    p.company,
    dp.package,
    dp.old_price,
    dp.price as new_price,
    dp.price - dp.old_price as price_difference,
    ROUND(((dp.price - dp.old_price) / dp.old_price * 100)::numeric, 2) as price_change_percentage,
    dp.price_updated_at as updated_at,
    'regular' as source
  FROM distributor_products dp
  JOIN products p ON dp.product_id = p.id
  WHERE dp.old_price IS NOT NULL
    AND dp.old_price != dp.price
    AND dp.price_updated_at >= (NOW() - INTERVAL '1 day' * days_ago)
  
  ORDER BY updated_at DESC;
END;
$$ LANGUAGE plpgsql;

-- تعليقات توضيحية
COMMENT ON COLUMN distributor_products.expiration_date IS 'تاريخ انتهاء صلاحية المنتج';
COMMENT ON COLUMN distributor_products.old_price IS 'السعر القديم قبل التحديث (لتتبع التغييرات)';
COMMENT ON COLUMN distributor_products.price_updated_at IS 'تاريخ آخر تحديث للسعر';

COMMENT ON FUNCTION get_expiring_products(int) IS 
'الحصول على جميع المنتجات قرب الانتهاء من كل الجداول (distributor_products + distributor_ocr_products)';

COMMENT ON FUNCTION get_price_changed_products(int) IS 
'الحصول على جميع المنتجات بتغيير سعر من كل الجداول (distributor_products + distributor_ocr_products)';
