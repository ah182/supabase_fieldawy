-- =====================================================
-- FINAL FIX - ANALYTICS TABLES WITH TEXT ID SUPPORT
-- =====================================================
-- هذا السكريبت يتعامل مع products.id سواء كان TEXT أو UUID

-- =====================================================
-- STEP 1: حذف الجداول القديمة
-- =====================================================

DROP TABLE IF EXISTS public.product_views CASCADE;
DROP TABLE IF EXISTS public.search_logs CASCADE;
DROP TABLE IF EXISTS public.activity_logs CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.user_activity_stats CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.product_performance_stats CASCADE;

-- =====================================================
-- STEP 2: Activity Logs (يعمل بغض النظر عن نوع products.id)
-- =====================================================

CREATE TABLE public.activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_type TEXT NOT NULL,
  user_id TEXT, -- TEXT لأن users.uid ممكن يكون TEXT
  user_name TEXT,
  user_role TEXT,
  description TEXT NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_activity_logs_created_at ON public.activity_logs(created_at DESC);
CREATE INDEX idx_activity_logs_type ON public.activity_logs(activity_type);
CREATE INDEX idx_activity_logs_user ON public.activity_logs(user_id);

-- RLS
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY activity_logs_select_all
ON public.activity_logs
FOR SELECT
USING (true); -- مؤقتاً للتجربة

CREATE POLICY activity_logs_insert_all
ON public.activity_logs
FOR INSERT
WITH CHECK (true); -- مؤقتاً للتجربة

-- =====================================================
-- STEP 3: Product Views (يعمل مع TEXT أو UUID)
-- =====================================================

CREATE TABLE public.product_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id TEXT NOT NULL, -- TEXT لأن products.id ممكن يكون TEXT
  user_id TEXT, -- TEXT لأن users.uid ممكن يكون TEXT
  user_role TEXT,
  viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_product_views_product ON public.product_views(product_id);
CREATE INDEX idx_product_views_user ON public.product_views(user_id);
CREATE INDEX idx_product_views_date ON public.product_views(viewed_at DESC);

-- RLS
ALTER TABLE public.product_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY product_views_select_all
ON public.product_views
FOR SELECT
USING (true);

CREATE POLICY product_views_insert_all
ON public.product_views
FOR INSERT
WITH CHECK (true);

-- =====================================================
-- STEP 4: Search Logs
-- =====================================================

CREATE TABLE public.search_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT,
  user_role TEXT,
  search_query TEXT NOT NULL,
  results_count INT DEFAULT 0,
  searched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_search_logs_user ON public.search_logs(user_id);
CREATE INDEX idx_search_logs_date ON public.search_logs(searched_at DESC);
CREATE INDEX idx_search_logs_query ON public.search_logs(search_query);

-- RLS
ALTER TABLE public.search_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY search_logs_select_all
ON public.search_logs
FOR SELECT
USING (true);

CREATE POLICY search_logs_insert_all
ON public.search_logs
FOR INSERT
WITH CHECK (true);

-- =====================================================
-- STEP 5: User Activity Stats (Materialized View)
-- =====================================================

CREATE MATERIALIZED VIEW public.user_activity_stats AS
SELECT 
  u.id AS user_id,
  u.display_name,
  u.email,
  u.role,
  u.account_status,
  u.created_at AS user_created_at,
  
  COALESCE(s.search_count, 0)::BIGINT AS total_searches,
  COALESCE(v.view_count, 0)::BIGINT AS total_views,
  COALESCE(p.product_count, 0)::BIGINT AS total_products,
  
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
) s ON u.id::TEXT = s.user_id
LEFT JOIN (
  SELECT user_id, COUNT(*) AS view_count, MAX(viewed_at) AS last_view
  FROM public.product_views
  GROUP BY user_id
) v ON u.id::TEXT = v.user_id
LEFT JOIN (
  SELECT distributor_id, COUNT(*) AS product_count
  FROM public.distributor_products
  GROUP BY distributor_id
) p ON u.id = p.distributor_id;

-- Indexes
CREATE UNIQUE INDEX idx_user_activity_stats_user_id 
ON public.user_activity_stats(user_id);

CREATE INDEX idx_user_activity_stats_role 
ON public.user_activity_stats(role);

CREATE INDEX idx_user_activity_stats_searches 
ON public.user_activity_stats(total_searches DESC);

-- =====================================================
-- STEP 6: Product Performance Stats (Materialized View)
-- =====================================================

CREATE MATERIALIZED VIEW public.product_performance_stats AS
SELECT 
  p.id::TEXT AS product_id,
  p.name AS product_name,
  p.company,
  NULL::NUMERIC AS price,
  NULL::TEXT AS distributor_id,
  NULL::TEXT AS distributor_name,
  p.created_at AS product_created_at,
  
  COALESCE(v.view_count, 0)::BIGINT AS total_views,
  COALESCE(v.doctor_views, 0)::BIGINT AS doctor_views,
  v.last_view AS last_viewed_at,
  COALESCE(dp.distributor_count, 0)::BIGINT AS distributor_count
  
FROM public.products p
LEFT JOIN (
  SELECT 
    product_id, 
    COUNT(*) AS view_count,
    COUNT(CASE WHEN user_role = 'doctor' THEN 1 END) AS doctor_views,
    MAX(viewed_at) AS last_view
  FROM public.product_views
  GROUP BY product_id
) v ON p.id::TEXT = v.product_id
LEFT JOIN (
  SELECT product_id::TEXT AS pid, COUNT(DISTINCT distributor_id) AS distributor_count
  FROM public.distributor_products
  GROUP BY product_id
) dp ON p.id::TEXT = dp.pid;

-- Indexes
CREATE UNIQUE INDEX idx_product_performance_stats_product_id 
ON public.product_performance_stats(product_id);

CREATE INDEX idx_product_performance_stats_views 
ON public.product_performance_stats(total_views DESC);

CREATE INDEX idx_product_performance_stats_doctor_views 
ON public.product_performance_stats(doctor_views DESC);

-- =====================================================
-- STEP 7: Helper Functions
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
  p_product_id TEXT,
  p_user_id TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_user_role TEXT;
  new_view_id UUID;
BEGIN
  IF p_user_id IS NOT NULL THEN
    SELECT role INTO v_user_role
    FROM public.users
    WHERE id::TEXT = p_user_id;
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
  p_user_id TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_user_role TEXT;
  new_log_id UUID;
BEGIN
  IF p_user_id IS NOT NULL THEN
    SELECT role INTO v_user_role
    FROM public.users
    WHERE id::TEXT = p_user_id;
  END IF;
  
  INSERT INTO public.search_logs (search_query, results_count, user_id, user_role)
  VALUES (p_search_query, p_results_count, p_user_id, v_user_role)
  RETURNING id INTO new_log_id;
  
  RETURN new_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION log_activity(
  p_activity_type TEXT,
  p_user_id TEXT DEFAULT NULL,
  p_user_name TEXT DEFAULT NULL,
  p_user_role TEXT DEFAULT NULL,
  p_description TEXT DEFAULT '',
  p_metadata JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_log_id UUID;
BEGIN
  INSERT INTO public.activity_logs (
    activity_type,
    user_id,
    user_name,
    user_role,
    description,
    metadata
  ) VALUES (
    p_activity_type,
    p_user_id,
    p_user_name,
    p_user_role,
    p_description,
    p_metadata
  )
  RETURNING id INTO new_log_id;
  
  RETURN new_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- STEP 8: Triggers for Auto-refresh
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
-- STEP 9: Triggers for Activity Logging
-- =====================================================

-- User Status Change
CREATE OR REPLACE FUNCTION trigger_log_user_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.account_status IS DISTINCT FROM NEW.account_status THEN
    PERFORM log_activity(
      CASE 
        WHEN NEW.account_status = 'approved' THEN 'user_approved'
        WHEN NEW.account_status = 'rejected' THEN 'user_rejected'
        ELSE 'user_status_changed'
      END,
      NEW.id::TEXT,
      NEW.display_name,
      NEW.role,
      format('%s was %s', COALESCE(NEW.display_name, 'User'), NEW.account_status),
      jsonb_build_object(
        'old_status', OLD.account_status,
        'new_status', NEW.account_status
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS log_user_status_change ON public.users;
CREATE TRIGGER log_user_status_change
AFTER UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION trigger_log_user_status_change();

-- =====================================================
-- STEP 10: Initial Refresh
-- =====================================================

SELECT refresh_user_activity_stats();
SELECT refresh_product_performance_stats();

-- =====================================================
-- STEP 11: Insert Sample Data for Testing
-- =====================================================

-- Sample activity log
SELECT log_activity(
  'system_started',
  NULL,
  'System',
  'admin',
  'Analytics system initialized successfully',
  jsonb_build_object('version', '1.0.0', 'timestamp', NOW()::TEXT)
);

-- =====================================================
-- SUCCESS!
-- =====================================================

SELECT 
  'SUCCESS! All analytics tables created!' AS status,
  (SELECT COUNT(*) FROM public.activity_logs) AS activity_logs_count,
  (SELECT COUNT(*) FROM public.product_views) AS product_views_count,
  (SELECT COUNT(*) FROM public.search_logs) AS search_logs_count,
  (SELECT COUNT(*) FROM public.user_activity_stats) AS user_stats_count,
  (SELECT COUNT(*) FROM public.product_performance_stats) AS product_stats_count;
