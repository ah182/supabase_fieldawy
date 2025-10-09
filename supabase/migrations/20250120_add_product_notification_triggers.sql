-- ============================================
-- إشعارات تلقائية عند إضافة/تحديث منتجات
-- ============================================

-- 1️⃣ دالة لإرسال webhook إلى notification server
CREATE OR REPLACE FUNCTION notify_product_change()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url text := 'http://YOUR_SERVER_IP:3000/api/notify/product-change';
  tab_name text;
  product_name text;
  v_expiration_date timestamp with time zone;
  v_old_price numeric;
BEGIN
  -- تحديد اسم المنتج بناءً على نوع الجدول
  IF TG_TABLE_NAME = 'products' THEN
    -- جدول products لديه عمود name
    product_name := COALESCE(NEW.name, 'منتج');
  ELSIF TG_TABLE_NAME = 'distributor_products' THEN
    -- جدول distributor_products يحتاج JOIN مع products
    -- نستخدم placeholder هنا والاسم الفعلي سيأتي من webhook server
    product_name := 'منتج';
  ELSIF TG_TABLE_NAME = 'ocr_products' THEN
    -- جدول ocr_products لديه product_name
    product_name := COALESCE(NEW.product_name, 'منتج OCR');
  ELSIF TG_TABLE_NAME = 'distributor_ocr_products' THEN
    -- distributor_ocr_products يحتاج JOIN - placeholder
    product_name := 'منتج OCR';
  ELSIF TG_TABLE_NAME = 'surgical_tools' THEN
    -- جدول surgical_tools لديه tool_name
    product_name := COALESCE(NEW.tool_name, 'أداة جراحية');
  ELSIF TG_TABLE_NAME = 'distributor_surgical_tools' THEN
    -- جدول distributor_surgical_tools يحتاج JOIN مع surgical_tools
    product_name := 'أداة جراحية'; -- placeholder
  ELSIF TG_TABLE_NAME = 'offers' THEN
    -- جدول offers لديه description فقط، ليس product_name
    product_name := COALESCE(NEW.description, 'عرض');
  ELSE
    product_name := 'منتج';
  END IF;

  -- تحديد التاب بناءً على نوع الجدول وخصائص المنتج
  IF TG_TABLE_NAME = 'surgical_tools' OR TG_TABLE_NAME = 'distributor_surgical_tools' THEN
    tab_name := 'surgical';
  ELSIF TG_TABLE_NAME = 'offers' THEN
    tab_name := 'offers';
  ELSIF TG_TABLE_NAME = 'distributor_ocr_products' THEN
    -- التحقق من تاريخ الانتهاء
    IF NEW.expiration_date IS NOT NULL AND 
       NEW.expiration_date <= (NOW() + INTERVAL '60 days') THEN
      tab_name := 'expire_soon';
    -- التحقق من تغيير السعر
    ELSIF NEW.old_price IS NOT NULL AND NEW.old_price != NEW.price THEN
      tab_name := 'price_action';
    ELSE
      tab_name := 'home';
    END IF;
  ELSIF TG_TABLE_NAME = 'distributor_products' THEN
    -- للمنتجات العادية: التحقق من السعر والانتهاء
    -- التحقق من تغيير السعر (عند UPDATE)
    IF TG_OP = 'UPDATE' AND OLD.price IS NOT NULL AND NEW.price IS NOT NULL AND OLD.price != NEW.price THEN
      tab_name := 'price_action';
    -- التحقق من تاريخ الانتهاء (إذا كان موجود في الجدول)
    ELSIF NEW.expiration_date IS NOT NULL AND 
          NEW.expiration_date > NOW() AND
          NEW.expiration_date <= (NOW() + INTERVAL '60 days') THEN
      tab_name := 'expire_soon';
    ELSE
      tab_name := 'home';
    END IF;
  ELSE
    tab_name := 'home';
  END IF;

  -- إرسال webhook (يتطلب تثبيت pg_net extension)
  -- للاستخدام المحلي، استخدم Supabase Edge Function أو HTTP Request من external service
  
  -- لأغراض التوثيق، نستخدم pg_notify بدلاً من HTTP
  -- في Production، استخدم Supabase Edge Function أو webhook service
  PERFORM pg_notify(
    'product_notification',
    json_build_object(
      'operation', TG_OP,
      'table', TG_TABLE_NAME,
      'product_name', product_name,
      'tab_name', tab_name
    )::text
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 2️⃣ إنشاء Triggers على جداول المنتجات
-- ============================================

-- Products table
DROP TRIGGER IF EXISTS trigger_notify_products ON products;
CREATE TRIGGER trigger_notify_products
AFTER INSERT OR UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION notify_product_change();

-- Distributor Products table
DROP TRIGGER IF EXISTS trigger_notify_distributor_products ON distributor_products;
CREATE TRIGGER trigger_notify_distributor_products
AFTER INSERT OR UPDATE ON distributor_products
FOR EACH ROW
EXECUTE FUNCTION notify_product_change();

-- OCR Products table
DROP TRIGGER IF EXISTS trigger_notify_ocr_products ON ocr_products;
CREATE TRIGGER trigger_notify_ocr_products
AFTER INSERT OR UPDATE ON ocr_products
FOR EACH ROW
EXECUTE FUNCTION notify_product_change();

-- Distributor OCR Products table
DROP TRIGGER IF EXISTS trigger_notify_distributor_ocr_products ON distributor_ocr_products;
CREATE TRIGGER trigger_notify_distributor_ocr_products
AFTER INSERT OR UPDATE ON distributor_ocr_products
FOR EACH ROW
EXECUTE FUNCTION notify_product_change();

-- Surgical Tools table
DROP TRIGGER IF EXISTS trigger_notify_surgical_tools ON surgical_tools;
CREATE TRIGGER trigger_notify_surgical_tools
AFTER INSERT OR UPDATE ON surgical_tools
FOR EACH ROW
EXECUTE FUNCTION notify_product_change();

-- Distributor Surgical Tools table
DROP TRIGGER IF EXISTS trigger_notify_distributor_surgical_tools ON distributor_surgical_tools;
CREATE TRIGGER trigger_notify_distributor_surgical_tools
AFTER INSERT OR UPDATE ON distributor_surgical_tools
FOR EACH ROW
EXECUTE FUNCTION notify_product_change();

-- Offers table (إذا كان موجود)
DROP TRIGGER IF EXISTS trigger_notify_offers ON offers;
CREATE TRIGGER trigger_notify_offers
AFTER INSERT OR UPDATE ON offers
FOR EACH ROW
EXECUTE FUNCTION notify_product_change();

-- ============================================
-- 3️⃣ دالة بديلة: استخدام Supabase Realtime
-- ============================================

-- يمكن استخدام Supabase Realtime API للاستماع للتغييرات
-- وإرسال الإشعارات من Backend (Node.js)

COMMENT ON FUNCTION notify_product_change() IS 
'يرسل إشعاراً عند إضافة أو تحديث منتج في أي جدول';

-- ============================================
-- 4️⃣ جدول تسجيل الإشعارات (اختياري)
-- ============================================

CREATE TABLE IF NOT EXISTS notification_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name text NOT NULL,
  operation text NOT NULL, -- INSERT, UPDATE
  product_name text,
  tab_name text,
  record_id uuid,
  sent_at timestamptz DEFAULT NOW(),
  status text DEFAULT 'pending', -- pending, sent, failed
  error_message text
);

CREATE INDEX idx_notification_logs_sent_at ON notification_logs(sent_at DESC);
CREATE INDEX idx_notification_logs_status ON notification_logs(status);

-- دالة لتسجيل الإشعارات
CREATE OR REPLACE FUNCTION log_notification(
  p_table_name text,
  p_operation text,
  p_product_name text,
  p_tab_name text,
  p_record_id uuid,
  p_status text DEFAULT 'sent',
  p_error_message text DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
  log_id uuid;
BEGIN
  INSERT INTO notification_logs (
    table_name,
    operation,
    product_name,
    tab_name,
    record_id,
    status,
    error_message
  ) VALUES (
    p_table_name,
    p_operation,
    p_product_name,
    p_tab_name,
    p_record_id,
    p_status,
    p_error_message
  )
  RETURNING id INTO log_id;
  
  RETURN log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 5️⃣ View لعرض إحصائيات الإشعارات
-- ============================================

CREATE OR REPLACE VIEW notification_stats AS
SELECT 
  DATE(sent_at) as date,
  table_name,
  tab_name,
  COUNT(*) as total_notifications,
  SUM(CASE WHEN status = 'sent' THEN 1 ELSE 0 END) as sent_count,
  SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_count
FROM notification_logs
GROUP BY DATE(sent_at), table_name, tab_name
ORDER BY date DESC, total_notifications DESC;

COMMENT ON VIEW notification_stats IS 
'إحصائيات الإشعارات المرسلة حسب التاريخ والجدول والتاب';
