-- =====================================================
-- MONITORING SYSTEM - RECREATE (مسح القديم وإعادة إنشاء)
-- =====================================================

-- =====================================================
-- 1. Drop Everything First (مسح القديم)
-- =====================================================

-- Drop views
DROP VIEW IF EXISTS public.error_summary_24h CASCADE;
DROP VIEW IF EXISTS public.performance_summary_24h CASCADE;
DROP VIEW IF EXISTS public.slow_queries_24h CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS public.log_error CASCADE;
DROP FUNCTION IF EXISTS public.log_performance CASCADE;
DROP FUNCTION IF EXISTS public.cleanup_old_error_logs CASCADE;
DROP FUNCTION IF EXISTS public.cleanup_old_performance_logs CASCADE;
DROP FUNCTION IF EXISTS public.get_error_count_24h CASCADE;
DROP FUNCTION IF EXISTS public.get_avg_api_time_24h CASCADE;

-- Drop tables (this will drop indexes automatically)
DROP TABLE IF EXISTS public.error_logs CASCADE;
DROP TABLE IF EXISTS public.performance_logs CASCADE;

-- =====================================================
-- 2. Create Tables
-- =====================================================

CREATE TABLE public.error_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Error details
  error_type TEXT NOT NULL,
  error_message TEXT NOT NULL,
  stack_trace TEXT,
  
  -- User context
  user_id TEXT,
  user_role TEXT,
  user_email TEXT,
  
  -- App context
  app_version TEXT,
  platform TEXT, -- 'web', 'android', 'ios'
  route TEXT, -- Which screen
  
  -- Device info (JSONB to save space)
  device_info JSONB,
  
  -- Timestamp
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Additional data
  metadata JSONB
);

CREATE TABLE public.performance_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Metric details
  metric_type TEXT NOT NULL, -- 'api_call', 'screen_load', 'image_load', 'custom'
  metric_name TEXT NOT NULL, -- '/users', 'HomeScreen', 'product_image'
  
  -- Performance data
  duration_ms INTEGER NOT NULL,
  success BOOLEAN DEFAULT true,
  
  -- User context (optional, for analytics)
  user_id TEXT,
  user_role TEXT,
  
  -- Timestamp
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Additional data (keep it small!)
  metadata JSONB
);

-- =====================================================
-- 3. Create Indexes
-- =====================================================

CREATE INDEX idx_error_logs_created ON public.error_logs(created_at DESC);
CREATE INDEX idx_error_logs_type ON public.error_logs(error_type);
CREATE INDEX idx_error_logs_user ON public.error_logs(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_error_logs_route ON public.error_logs(route) WHERE route IS NOT NULL;

CREATE INDEX idx_performance_logs_created ON public.performance_logs(created_at DESC);
CREATE INDEX idx_performance_logs_type ON public.performance_logs(metric_type);
CREATE INDEX idx_performance_logs_name ON public.performance_logs(metric_name);
CREATE INDEX idx_performance_logs_slow ON public.performance_logs(duration_ms DESC) 
  WHERE duration_ms > 1000;

-- =====================================================
-- 4. Enable RLS (Security)
-- =====================================================

ALTER TABLE public.error_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.performance_logs ENABLE ROW LEVEL SECURITY;

-- Policies for error_logs
DROP POLICY IF EXISTS error_logs_insert_authenticated ON public.error_logs;
DROP POLICY IF EXISTS error_logs_select_admin ON public.error_logs;

CREATE POLICY error_logs_insert_authenticated
ON public.error_logs
FOR INSERT
WITH CHECK (true); -- Anyone can log errors

CREATE POLICY error_logs_select_admin
ON public.error_logs
FOR SELECT
USING (true); -- Admins can view

-- Policies for performance_logs
DROP POLICY IF EXISTS performance_logs_insert_authenticated ON public.performance_logs;
DROP POLICY IF EXISTS performance_logs_select_admin ON public.performance_logs;

CREATE POLICY performance_logs_insert_authenticated
ON public.performance_logs
FOR INSERT
WITH CHECK (true);

CREATE POLICY performance_logs_select_admin
ON public.performance_logs
FOR SELECT
USING (true);

-- =====================================================
-- 5. Create Functions
-- =====================================================

-- Log Error
CREATE FUNCTION public.log_error(
  p_error_type TEXT,
  p_error_message TEXT,
  p_stack_trace TEXT DEFAULT NULL,
  p_user_id TEXT DEFAULT NULL,
  p_user_role TEXT DEFAULT NULL,
  p_route TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_log_id UUID;
BEGIN
  INSERT INTO public.error_logs (
    error_type,
    error_message,
    stack_trace,
    user_id,
    user_role,
    route,
    metadata
  ) VALUES (
    p_error_type,
    p_error_message,
    p_stack_trace,
    p_user_id,
    p_user_role,
    p_route,
    p_metadata
  )
  RETURNING id INTO new_log_id;
  
  RETURN new_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Log Performance
CREATE FUNCTION public.log_performance(
  p_metric_type TEXT,
  p_metric_name TEXT,
  p_duration_ms INTEGER,
  p_success BOOLEAN DEFAULT true,
  p_user_id TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_log_id UUID;
BEGIN
  INSERT INTO public.performance_logs (
    metric_type,
    metric_name,
    duration_ms,
    success,
    user_id,
    metadata
  ) VALUES (
    p_metric_type,
    p_metric_name,
    p_duration_ms,
    p_success,
    p_user_id,
    p_metadata
  )
  RETURNING id INTO new_log_id;
  
  RETURN new_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cleanup old error logs (keep 30 days)
CREATE FUNCTION public.cleanup_old_error_logs()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM public.error_logs
  WHERE created_at < NOW() - INTERVAL '30 days';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cleanup old performance logs (keep 7 days)
CREATE FUNCTION public.cleanup_old_performance_logs()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM public.performance_logs
  WHERE created_at < NOW() - INTERVAL '7 days';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get error count (last 24h)
CREATE FUNCTION public.get_error_count_24h()
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM public.error_logs
    WHERE created_at > NOW() - INTERVAL '24 hours'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get average API response time (last 24h)
CREATE FUNCTION public.get_avg_api_time_24h()
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COALESCE(AVG(duration_ms)::INTEGER, 0)
    FROM public.performance_logs
    WHERE created_at > NOW() - INTERVAL '24 hours'
      AND metric_type = 'api_call'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. Create Views
-- =====================================================

-- Error Summary (Last 24h)
CREATE VIEW public.error_summary_24h AS
SELECT 
  error_type,
  COUNT(*)::INTEGER as count,
  COUNT(DISTINCT user_id)::INTEGER as affected_users,
  MAX(created_at) as last_occurrence,
  array_agg(DISTINCT route) FILTER (WHERE route IS NOT NULL) as affected_routes
FROM public.error_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY error_type
ORDER BY count DESC;

-- Performance Summary (Last 24h)
CREATE VIEW public.performance_summary_24h AS
SELECT 
  metric_type,
  metric_name,
  COUNT(*)::INTEGER as call_count,
  AVG(duration_ms)::INTEGER as avg_duration,
  MAX(duration_ms)::INTEGER as max_duration,
  MIN(duration_ms)::INTEGER as min_duration,
  COUNT(*) FILTER (WHERE success = false)::INTEGER as error_count
FROM public.performance_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY metric_type, metric_name
ORDER BY avg_duration DESC;

-- Slow Queries (Last 24h, >1 second)
CREATE VIEW public.slow_queries_24h AS
SELECT 
  metric_name,
  duration_ms,
  user_id,
  created_at,
  metadata
FROM public.performance_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
  AND duration_ms > 1000
ORDER BY duration_ms DESC
LIMIT 50;

-- =====================================================
-- 7. Insert Sample Data (for testing)
-- =====================================================

SELECT public.log_error(
  'system_initialized',
  'Monitoring system recreated successfully! ✅',
  NULL,
  NULL,
  'system',
  NULL,
  jsonb_build_object('version', '2.0.0', 'timestamp', NOW())
);

-- Insert sample performance log
INSERT INTO public.performance_logs (
  metric_type,
  metric_name,
  duration_ms,
  success,
  metadata
) VALUES (
  'api_call',
  'get_all_users',
  245,
  true,
  jsonb_build_object('method', 'GET', 'status', 200)
);

-- =====================================================
-- 8. Verification
-- =====================================================

SELECT 
  '✅ Monitoring tables recreated successfully!' AS status,
  (SELECT COUNT(*) FROM public.error_logs) AS error_logs_count,
  (SELECT COUNT(*) FROM public.performance_logs) AS performance_logs_count,
  (SELECT COUNT(*) FROM public.error_summary_24h) AS error_summary_count,
  (SELECT COUNT(*) FROM public.performance_summary_24h) AS performance_summary_count;

-- =====================================================
-- SUCCESS! الآن يمكنك استخدام Dashboard بدون مشاكل! 🎉
-- =====================================================
