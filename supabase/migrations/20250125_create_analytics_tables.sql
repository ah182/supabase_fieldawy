-- =====================================================
-- Analytics Tables for Top Performers & User Tracking
-- =====================================================

-- =====================================================
-- 1. Product Views Table
-- =====================================================
CREATE TABLE IF NOT EXISTS public.product_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(uid) ON DELETE SET NULL,
  user_role TEXT, -- 'doctor', 'distributor', 'company', 'viewer'
  viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_product_views_product ON public.product_views(product_id);
CREATE INDEX IF NOT EXISTS idx_product_views_user ON public.product_views(user_id);
CREATE INDEX IF NOT EXISTS idx_product_views_date ON public.product_views(viewed_at DESC);

-- RLS
ALTER TABLE public.product_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY product_views_insert_authenticated
ON public.product_views
FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY product_views_admin_select
ON public.product_views
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE uid = auth.uid()
    AND role = 'admin'
  )
);

-- =====================================================
-- 2. Search Logs Table
-- =====================================================
CREATE TABLE IF NOT EXISTS public.search_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(uid) ON DELETE SET NULL,
  user_role TEXT,
  search_query TEXT NOT NULL,
  results_count INT DEFAULT 0,
  searched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_search_logs_user ON public.search_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_search_logs_date ON public.search_logs(searched_at DESC);
CREATE INDEX IF NOT EXISTS idx_search_logs_query ON public.search_logs(search_query);

-- RLS
ALTER TABLE public.search_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY search_logs_insert_authenticated
ON public.search_logs
FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY search_logs_admin_select
ON public.search_logs
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE uid = auth.uid()
    AND role = 'admin'
  )
);

-- =====================================================
-- 3. User Activity Stats (Materialized View)
-- =====================================================
-- هذا view يعطينا إحصائيات سريعة عن نشاط كل مستخدم

CREATE MATERIALIZED VIEW IF NOT EXISTS public.user_activity_stats AS
SELECT 
  u.uid AS user_id,
  u.display_name,
  u.email,
  u.role,
  u.account_status,
  u.created_at AS user_created_at,
  
  -- عدد عمليات البحث
  COALESCE(s.search_count, 0) AS total_searches,
  
  -- عدد المشاهدات
  COALESCE(v.view_count, 0) AS total_views,
  
  -- عدد المنتجات (للموزعين)
  COALESCE(p.product_count, 0) AS total_products,
  
  -- آخر نشاط
  GREATEST(
    COALESCE(s.last_search, u.created_at),
    COALESCE(v.last_view, u.created_at),
    u.created_at
  ) AS last_activity_at
  
FROM public.users u
LEFT JOIN (
  SELECT user_id, COUNT(*) AS search_count, MAX(searched_at) AS last_search
  FROM public.search_logs
  GROUP BY user_id
) s ON u.uid = s.user_id
LEFT JOIN (
  SELECT user_id, COUNT(*) AS view_count, MAX(viewed_at) AS last_view
  FROM public.product_views
  GROUP BY user_id
) v ON u.uid = v.user_id
LEFT JOIN (
  SELECT distributor_id, COUNT(*) AS product_count
  FROM public.distributor_products
  GROUP BY distributor_id
) p ON u.uid = p.distributor_id;

-- Index للـ Materialized View
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_activity_stats_user_id 
ON public.user_activity_stats(user_id);

CREATE INDEX IF NOT EXISTS idx_user_activity_stats_role 
ON public.user_activity_stats(role);

CREATE INDEX IF NOT EXISTS idx_user_activity_stats_searches 
ON public.user_activity_stats(total_searches DESC);

-- Function لتحديث الـ Materialized View
CREATE OR REPLACE FUNCTION refresh_user_activity_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.user_activity_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. Product Performance Stats (Materialized View)
-- =====================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS public.product_performance_stats AS
SELECT 
  p.id AS product_id,
  p.name AS product_name,
  p.company,
  p.price,
  p.distributor_id,
  u.display_name AS distributor_name,
  p.created_at AS product_created_at,
  
  -- عدد المشاهدات
  COALESCE(v.view_count, 0) AS total_views,
  
  -- عدد المشاهدات من الأطباء
  COALESCE(v.doctor_views, 0) AS doctor_views,
  
  -- آخر مشاهدة
  v.last_view AS last_viewed_at,
  
  -- عدد الموزعين الذين يبيعون هذا المنتج
  COALESCE(dp.distributor_count, 0) AS distributor_count
  
FROM public.products p
LEFT JOIN public.users u ON p.distributor_id = u.uid
LEFT JOIN (
  SELECT 
    product_id, 
    COUNT(*) AS view_count,
    COUNT(CASE WHEN user_role = 'doctor' THEN 1 END) AS doctor_views,
    MAX(viewed_at) AS last_view
  FROM public.product_views
  GROUP BY product_id
) v ON p.id = v.product_id
LEFT JOIN (
  SELECT product_id, COUNT(DISTINCT distributor_id) AS distributor_count
  FROM public.distributor_products
  GROUP BY product_id
) dp ON p.id = dp.product_id;

-- Index للـ Materialized View
CREATE UNIQUE INDEX IF NOT EXISTS idx_product_performance_stats_product_id 
ON public.product_performance_stats(product_id);

CREATE INDEX IF NOT EXISTS idx_product_performance_stats_views 
ON public.product_performance_stats(total_views DESC);

CREATE INDEX IF NOT EXISTS idx_product_performance_stats_doctor_views 
ON public.product_performance_stats(doctor_views DESC);

-- Function لتحديث الـ Materialized View
CREATE OR REPLACE FUNCTION refresh_product_performance_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.product_performance_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. Helper Functions
-- =====================================================

-- Log product view
CREATE OR REPLACE FUNCTION log_product_view(
  p_product_id UUID,
  p_user_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_user_role TEXT;
  new_view_id UUID;
BEGIN
  -- Get user role if user_id provided
  IF p_user_id IS NOT NULL THEN
    SELECT role INTO v_user_role
    FROM public.users
    WHERE uid = p_user_id;
  END IF;
  
  INSERT INTO public.product_views (product_id, user_id, user_role)
  VALUES (p_product_id, p_user_id, v_user_role)
  RETURNING id INTO new_view_id;
  
  RETURN new_view_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Log search query
CREATE OR REPLACE FUNCTION log_search(
  p_search_query TEXT,
  p_results_count INT DEFAULT 0,
  p_user_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_user_role TEXT;
  new_log_id UUID;
BEGIN
  -- Get user role if user_id provided
  IF p_user_id IS NOT NULL THEN
    SELECT role INTO v_user_role
    FROM public.users
    WHERE uid = p_user_id;
  END IF;
  
  INSERT INTO public.search_logs (search_query, results_count, user_id, user_role)
  VALUES (p_search_query, p_results_count, p_user_id, v_user_role)
  RETURNING id INTO new_log_id;
  
  RETURN new_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get top products by views
CREATE OR REPLACE FUNCTION get_top_products_by_views(
  p_limit INT DEFAULT 10
)
RETURNS TABLE (
  product_id UUID,
  product_name TEXT,
  company TEXT,
  total_views BIGINT,
  doctor_views BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pps.product_id,
    pps.product_name,
    pps.company,
    pps.total_views,
    pps.doctor_views
  FROM public.product_performance_stats pps
  ORDER BY pps.total_views DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get top users by activity
CREATE OR REPLACE FUNCTION get_top_users_by_activity(
  p_role TEXT DEFAULT NULL,
  p_limit INT DEFAULT 10
)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  email TEXT,
  role TEXT,
  total_searches BIGINT,
  total_views BIGINT,
  total_products BIGINT
) AS $$
BEGIN
  IF p_role IS NOT NULL THEN
    RETURN QUERY
    SELECT 
      uas.user_id,
      uas.display_name,
      uas.email,
      uas.role,
      uas.total_searches,
      uas.total_views,
      uas.total_products
    FROM public.user_activity_stats uas
    WHERE uas.role = p_role
    ORDER BY (uas.total_searches + uas.total_views) DESC
    LIMIT p_limit;
  ELSE
    RETURN QUERY
    SELECT 
      uas.user_id,
      uas.display_name,
      uas.email,
      uas.role,
      uas.total_searches,
      uas.total_views,
      uas.total_products
    FROM public.user_activity_stats uas
    ORDER BY (uas.total_searches + uas.total_views) DESC
    LIMIT p_limit;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. Auto-refresh Materialized Views (Trigger-based)
-- =====================================================
-- نحدّث الـ stats كل ما في نشاط جديد

CREATE OR REPLACE FUNCTION trigger_refresh_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Refresh في الخلفية (asynchronous)
  PERFORM refresh_user_activity_stats();
  PERFORM refresh_product_performance_stats();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers
DROP TRIGGER IF EXISTS refresh_stats_on_view ON public.product_views;
CREATE TRIGGER refresh_stats_on_view
AFTER INSERT ON public.product_views
FOR EACH STATEMENT
EXECUTE FUNCTION trigger_refresh_stats();

DROP TRIGGER IF EXISTS refresh_stats_on_search ON public.search_logs;
CREATE TRIGGER refresh_stats_on_search
AFTER INSERT ON public.search_logs
FOR EACH STATEMENT
EXECUTE FUNCTION trigger_refresh_stats();

-- =====================================================
-- Initial refresh
-- =====================================================
SELECT refresh_user_activity_stats();
SELECT refresh_product_performance_stats();

-- =====================================================
-- Sample data (for testing - optional)
-- =====================================================
-- يمكنك حذف هذا القسم

-- INSERT INTO public.product_views (product_id, user_role) 
-- SELECT id, 'doctor' FROM public.products LIMIT 5;

-- INSERT INTO public.search_logs (search_query, results_count, user_role)
-- VALUES ('Amoxicillin', 15, 'doctor');
