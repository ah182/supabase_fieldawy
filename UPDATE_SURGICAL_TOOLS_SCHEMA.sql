-- 1. تعديل جدول أدوات الموزع للسماح بالأدوات الخاصة (غير المرتبطة بالكتالوج العام)
ALTER TABLE distributor_surgical_tools ALTER COLUMN surgical_tool_id DROP NOT NULL;

ALTER TABLE distributor_surgical_tools ADD COLUMN IF NOT EXISTS tool_name text;
ALTER TABLE distributor_surgical_tools ADD COLUMN IF NOT EXISTS company text;
ALTER TABLE distributor_surgical_tools ADD COLUMN IF NOT EXISTS image_url text;

-- 2. تحديث دالة جلب أدوات الموزع لتشمل الأدوات الخاصة
CREATE OR REPLACE FUNCTION get_distributor_surgical_tools(dist_id uuid)
RETURNS TABLE (
  id uuid,
  tool_name text,
  company text,
  description text,
  image_url text,
  price numeric,
  created_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dst.id,
    COALESCE(st.tool_name, dst.tool_name) as tool_name,
    COALESCE(st.company, dst.company) as company,
    dst.description,
    COALESCE(st.image_url, dst.image_url) as image_url,
    dst.price,
    dst.created_at
  FROM distributor_surgical_tools dst
  LEFT JOIN surgical_tools st ON dst.surgical_tool_id = st.id
  WHERE dst.distributor_id = dist_id
  ORDER BY dst.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 3. تحديث دالة البحث لتشمل الأدوات الخاصة
CREATE OR REPLACE FUNCTION search_surgical_tools(search_query text)
RETURNS TABLE (
  id uuid,
  tool_name text,
  company text,
  description text,
  image_url text,
  price numeric,
  distributor_name text,
  distributor_id uuid
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dst.id,
    COALESCE(st.tool_name, dst.tool_name) as tool_name,
    COALESCE(st.company, dst.company) as company,
    dst.description,
    COALESCE(st.image_url, dst.image_url) as image_url,
    dst.price,
    dst.distributor_name,
    dst.distributor_id
  FROM distributor_surgical_tools dst
  LEFT JOIN surgical_tools st ON dst.surgical_tool_id = st.id
  WHERE 
    COALESCE(st.tool_name, dst.tool_name) ILIKE '%' || search_query || '%'
    OR COALESCE(st.company, dst.company) ILIKE '%' || search_query || '%'
    OR dst.description ILIKE '%' || search_query || '%'
  ORDER BY dst.created_at DESC;
END;
$$ LANGUAGE plpgsql;
