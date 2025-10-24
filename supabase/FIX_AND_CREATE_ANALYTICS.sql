-- =====================================================
-- FIX & CREATE ANALYTICS TABLES
-- هذا السكريبت يصلح أي مشاكل ثم ينشئ الجداول
-- =====================================================

-- =====================================================
-- STEP 1: التحقق من وجود الجداول وحذفها إذا كانت موجودة
-- =====================================================

-- Drop existing tables if any (لبداية نظيفة)
DROP TABLE IF EXISTS public.product_views CASCADE;
DROP TABLE IF EXISTS public.search_logs CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.user_activity_stats CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.product_performance_stats CASCADE;

-- =====================================================
-- STEP 2: Product Views Table
-- =====================================================

CREATE TABLE public.product_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL,
  user_id UUID,
  user_role TEXT,
  viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Foreign Keys (بدون REFERENCES للتأكد من عدم وجود مشاكل نوع البيانات)
  CONSTRAINT fk_product_views_product 
    FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE,
  CONSTRAINT fk_product_views_user 
    FOREIGN KEY (user_id) REFERENCES public.users(uid) ON DELETE SET NULL
);

-- Indexes
CREATE INDEX idx_product_views_product ON public.product_views(product_id);
CREATE INDEX idx_product_views_user ON public.product_views(user_id);
CREATE INDEX idx_product_views_date ON public.product_views(viewed_at DESC);

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
-- STEP 3: Search Logs Table
-- =====================================================

CREATE TABLE public.search_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  user_role TEXT,
  search_query TEXT NOT NULL,
  results_count INT DEFAULT 0,
  searched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT fk_search_logs_user 
    FOREIGN KEY (user_id) REFERENCES public.users(uid) ON DELETE SET NULL
);

-- Indexes
CREATE INDEX idx_search_logs_user ON public.search_logs(user_id);
CREATE INDEX idx_search_logs_date ON public.search_logs(searched_at DESC);
CREATE INDEX idx_search_logs_query ON public.search_logs(search_query);

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
-- STEP 4: User Activity Stats (Materialized View)
-- =====================================================

CREATE MATERIALIZED VIEW public.user_activity_stats AS
SELECT 
  u.uid AS user_id,
  u.display_name,
  u.email,
  u.role,
  u.account_status,
  u.created_at AS user_created_at,
  
  COALESCE(s.search_count, 0) AS total_searches,
  COALESCE(v.view_count, 0) AS total_views,
  COALESCE(p.product_count, 0) AS total_products,
  
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

-- Indexes
CREATE UNIQUE INDEX idx_user_activity_stats_user_id 
ON public.user_activity_stats(user_id);

CREATE INDEX idx_user_activity_stats_role 
ON public.user_activity_stats(role);

CREATE INDEX idx_user_activity_stats_searches 
ON public.user_activity_stats(total_searches DESC);

-- =====================================================
-- STEP 5: Product Performance Stats (Materialized View)
-- =====================================================

CREATE MATERIALIZED VIEW public.product_performance_stats AS
SELECT 
  p.id AS product_id,
  p.name AS product_name,
  p.company,
  p.price,
  p.distributor_id,
  u.display_name AS distributor_name,
  p.created_at AS product_created_at,
  
  COALESCE(v.view_count, 0) AS total_views,
  COALESCE(v.doctor_views, 0) AS doctor_views,
  v.last_view AS last_viewed_at,
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

-- Indexes
CREATE UNIQUE INDEX idx_product_performance_stats_product_id 
ON public.product_performance_stats(product_id);

CREATE INDEX idx_product_performance_stats_views 
ON public.product_performance_stats(total_views DESC);

CREATE INDEX idx_product_performance_stats_doctor_views 
ON public.product_performance_stats(doctor_views DESC);

-- =====================================================
-- STEP 6: Helper Functions
-- =====================================================

-- Refresh Functions
CREATE OR REPLACE FUNCTION refresh_user_activity_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.user_activity_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION refresh_product_performance_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.product_performance_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Log Functions
CREATE OR REPLACE FUNCTION log_product_view(
  p_product_id UUID,
  p_user_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_user_role TEXT;
  new_view_id UUID;
BEGIN
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

-- =====================================================
-- STEP 7: Triggers for Auto-refresh
-- =====================================================

CREATE OR REPLACE FUNCTION trigger_refresh_stats()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM refresh_user_activity_stats();
  PERFORM refresh_product_performance_stats();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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
-- STEP 8: Initial Refresh
-- =====================================================

SELECT refresh_user_activity_stats();
SELECT refresh_product_performance_stats();

-- =====================================================
-- SUCCESS!
-- =====================================================

SELECT 'Analytics tables created successfully!' AS status;
