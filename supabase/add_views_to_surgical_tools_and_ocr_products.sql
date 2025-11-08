-- إضافة عمود views لجدولي surgical_tools و ocr_products وحساب المجموع من الموزعين
-- Add views column to surgical_tools and ocr_products tables and calculate totals

-- 1. إضافة عمود views إلى جدول surgical_tools
ALTER TABLE surgical_tools 
ADD COLUMN IF NOT EXISTS views BIGINT DEFAULT 0;

-- 2. إضافة عمود views إلى جدول ocr_products
ALTER TABLE ocr_products 
ADD COLUMN IF NOT EXISTS views BIGINT DEFAULT 0;

-- 3. دالة لحساب وتحديث مجموع المشاهدات للأدوات الجراحية
CREATE OR REPLACE FUNCTION update_surgical_tool_total_views(p_tool_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_views BIGINT := 0;
BEGIN
    -- حساب مجموع المشاهدات من جدول distributor_surgical_tools
    SELECT COALESCE(SUM(views), 0) INTO total_views
    FROM distributor_surgical_tools
    WHERE surgical_tool_id = p_tool_id;
    
    -- تحديث العمود في جدول surgical_tools
    UPDATE surgical_tools 
    SET views = total_views
    WHERE id = p_tool_id;
    
    RAISE NOTICE 'Updated surgical tool % views to %', p_tool_id, total_views;
END;
$$;

-- 4. دالة لحساب وتحديث مجموع المشاهدات لمنتجات OCR
CREATE OR REPLACE FUNCTION update_ocr_product_total_views(p_product_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_views BIGINT := 0;
BEGIN
    -- حساب مجموع المشاهدات من جدول distributor_ocr_products
    SELECT COALESCE(SUM(views), 0) INTO total_views
    FROM distributor_ocr_products
    WHERE ocr_product_id = p_product_id;
    
    -- تحديث العمود في جدول ocr_products
    UPDATE ocr_products 
    SET views = total_views
    WHERE id = p_product_id;
    
    RAISE NOTICE 'Updated OCR product % views to %', p_product_id, total_views;
END;
$$;

-- 5. دالة لتحديث جميع الأدوات الجراحية
CREATE OR REPLACE FUNCTION update_all_surgical_tools_views()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    tool_id UUID;
    total_updated INTEGER := 0;
BEGIN
    RAISE NOTICE 'Starting to update views for all surgical tools...';
    
    -- الحصول على معرفات الأدوات الجراحية الموجودة فعلياً
    FOR tool_id IN 
        SELECT DISTINCT st.id
        FROM surgical_tools st
        WHERE st.id IS NOT NULL 
          AND EXISTS (
              SELECT 1 FROM distributor_surgical_tools dst 
              WHERE dst.surgical_tool_id = st.id
          )
    LOOP
        PERFORM update_surgical_tool_total_views(tool_id);
        total_updated := total_updated + 1;
    END LOOP;
    
    RAISE NOTICE 'Updated views for % surgical tools', total_updated;
END;
$$;

-- 6. دالة لتحديث جميع منتجات OCR
CREATE OR REPLACE FUNCTION update_all_ocr_products_views()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    product_id UUID;
    total_updated INTEGER := 0;
BEGIN
    RAISE NOTICE 'Starting to update views for all OCR products...';
    
    -- الحصول على معرفات منتجات OCR الموجودة فعلياً
    FOR product_id IN 
        SELECT DISTINCT op.id
        FROM ocr_products op
        WHERE op.id IS NOT NULL 
          AND EXISTS (
              SELECT 1 FROM distributor_ocr_products dop 
              WHERE dop.ocr_product_id = op.id
          )
    LOOP
        PERFORM update_ocr_product_total_views(product_id);
        total_updated := total_updated + 1;
    END LOOP;
    
    RAISE NOTICE 'Updated views for % OCR products', total_updated;
END;
$$;

-- 7. إنشاء triggers للتحديث التلقائي للأدوات الجراحية
CREATE OR REPLACE FUNCTION trigger_update_surgical_tool_views()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        PERFORM update_surgical_tool_total_views(NEW.surgical_tool_id);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM update_surgical_tool_total_views(OLD.surgical_tool_id);
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$;

-- 8. إنشاء triggers للتحديث التلقائي لمنتجات OCR
CREATE OR REPLACE FUNCTION trigger_update_ocr_product_views()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        PERFORM update_ocr_product_total_views(NEW.ocr_product_id);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM update_ocr_product_total_views(OLD.ocr_product_id);
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$;

-- 9. تطبيق triggers على الجداول
DROP TRIGGER IF EXISTS update_surgical_tool_views_trigger ON distributor_surgical_tools;
CREATE TRIGGER update_surgical_tool_views_trigger
    AFTER INSERT OR UPDATE OR DELETE ON distributor_surgical_tools
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_surgical_tool_views();

DROP TRIGGER IF EXISTS update_ocr_product_views_trigger ON distributor_ocr_products;
CREATE TRIGGER update_ocr_product_views_trigger
    AFTER INSERT OR UPDATE OR DELETE ON distributor_ocr_products
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_ocr_product_views();

-- 10. تشغيل التحديث الأولي
SELECT update_all_surgical_tools_views();
SELECT update_all_ocr_products_views();

-- 11. إنشاء فهارس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_surgical_tools_views ON surgical_tools(views DESC);
CREATE INDEX IF NOT EXISTS idx_ocr_products_views ON ocr_products(views DESC);
CREATE INDEX IF NOT EXISTS idx_distributor_surgical_tools_views ON distributor_surgical_tools(surgical_tool_id, views);
CREATE INDEX IF NOT EXISTS idx_distributor_ocr_products_views ON distributor_ocr_products(ocr_product_id, views);

-- 12. دوال للحصول على أشهر الأدوات الجراحية ومنتجات OCR
CREATE OR REPLACE FUNCTION get_top_viewed_surgical_tools(
    exclude_user_id UUID DEFAULT NULL,
    limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    tool_name TEXT,
    views BIGINT,
    distributor_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        st.id,
        st.tool_name,
        st.views,
        COUNT(DISTINCT dst.distributor_id) as distributor_count
    FROM surgical_tools st
    LEFT JOIN distributor_surgical_tools dst ON st.id = dst.surgical_tool_id
    WHERE (exclude_user_id IS NULL OR st.id NOT IN (
        SELECT surgical_tool_id 
        FROM distributor_surgical_tools 
        WHERE distributor_id = exclude_user_id
    ))
    GROUP BY st.id, st.tool_name, st.views
    ORDER BY st.views DESC, distributor_count DESC
    LIMIT limit_count;
END;
$$;

CREATE OR REPLACE FUNCTION get_top_viewed_ocr_products(
    exclude_user_id UUID DEFAULT NULL,
    limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    product_name TEXT,
    views BIGINT,
    distributor_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        op.id,
        op.product_name,
        op.views,
        COUNT(DISTINCT dop.distributor_id) as distributor_count
    FROM ocr_products op
    LEFT JOIN distributor_ocr_products dop ON op.id = dop.ocr_product_id
    WHERE (exclude_user_id IS NULL OR op.id NOT IN (
        SELECT ocr_product_id 
        FROM distributor_ocr_products 
        WHERE distributor_id = exclude_user_id
    ))
    GROUP BY op.id, op.product_name, op.views
    ORDER BY op.views DESC, distributor_count DESC
    LIMIT limit_count;
END;
$$;

-- 13. منح الصلاحيات
GRANT EXECUTE ON FUNCTION update_surgical_tool_total_views TO authenticated;
GRANT EXECUTE ON FUNCTION update_ocr_product_total_views TO authenticated;
GRANT EXECUTE ON FUNCTION update_all_surgical_tools_views TO authenticated;
GRANT EXECUTE ON FUNCTION update_all_ocr_products_views TO authenticated;
GRANT EXECUTE ON FUNCTION get_top_viewed_surgical_tools TO authenticated;
GRANT EXECUTE ON FUNCTION get_top_viewed_ocr_products TO authenticated;

-- 14. عرض النتائج
SELECT 
    COUNT(*) as total_surgical_tools,
    COUNT(CASE WHEN views > 0 THEN 1 END) as tools_with_views,
    MAX(views) as max_views,
    AVG(views) as avg_views
FROM surgical_tools;

SELECT 
    COUNT(*) as total_ocr_products,
    COUNT(CASE WHEN views > 0 THEN 1 END) as products_with_views,
    MAX(views) as max_views,
    AVG(views) as avg_views
FROM ocr_products;

SELECT 'Surgical tools and OCR products views setup completed successfully!' as status;
SELECT 'Views will be automatically updated when distributor tables change' as auto_update_info;