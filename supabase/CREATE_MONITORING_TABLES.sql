-- =====================================================
-- MONITORING SYSTEM - FREE TIER OPTIMIZED
-- =====================================================
-- كل شيء مصمم ليكون مجاني للأبد!

-- =====================================================
-- 1. Error Logs Table
-- =====================================================

CREATE TABLE IF NOT EXISTS public.error_logs (
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

-- Indexes (for fast queries)
CREATE INDEX idx_error_logs_created ON public.error_logs(created_at DESC);
CREATE INDEX idx_error_logs_type ON public.error_logs(error_type);
CREATE INDEX idx_error_logs_user ON public.error_logs(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_error_logs_route ON public.error_logs(route) WHERE route IS NOT NULL;

-- RLS (Security)
ALTER TABLE public.error_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY error_logs_insert_authenticated
ON public.error_logs
FOR INSERT
WITH CHECK (true); -- Anyone can log errors

CREATE POLICY error_logs_select_admin
ON public.error_logs
FOR SELECT
USING (true); -- Admins can view (adjust based on your needs)

-- =====================================================
-- 2. Performance Logs Table
-- =====================================================

CREATE TABLE IF NOT EXISTS public.performance_logs (
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

-- Indexes
CREATE INDEX idx_performance_logs_created ON public.performance_logs(created_at DESC);
CREATE INDEX idx_performance_logs_type ON public.performance_logs(metric_type);
CREATE INDEX idx_performance_logs_name ON public.performance_logs(metric_name);
CREATE INDEX idx_performance_logs_slow ON public.performance_logs(duration_ms DESC) 
  WHERE duration_ms > 1000; -- Only index slow queries

-- RLS
ALTER TABLE public.performance_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY performance_logs_insert_authenticated
ON public.performance_logs
FOR INSERT
WITH CHECK (true);

CREATE POLICY performance_logs_select_admin
ON public.performance_logs
FOR SELECT
USING (true);

-- =====================================================
-- 3. Helper Functions
-- =====================================================

-- Log Error (from Flutter)
CREATE OR REPLACE FUNCTION log_error(
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

-- Log Performance Metric
CREATE OR REPLACE FUNCTION log_performance(
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

-- =====================================================
-- 4. Analytics Views (Fast Queries)
-- =====================================================

-- Error Summary (Last 24h)
CREATE OR REPLACE VIEW error_summary_24h AS
SELECT 
  error_type,
  COUNT(*) as count,
  COUNT(DISTINCT user_id) as affected_users,
  MAX(created_at) as last_occurrence,
  array_agg(DISTINCT route) FILTER (WHERE route IS NOT NULL) as affected_routes
FROM public.error_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY error_type
ORDER BY count DESC;

-- Performance Summary (Last 24h)
CREATE OR REPLACE VIEW performance_summary_24h AS
SELECT 
  metric_type,
  metric_name,
  COUNT(*) as call_count,
  AVG(duration_ms)::INTEGER as avg_duration,
  MAX(duration_ms) as max_duration,
  MIN(duration_ms) as min_duration,
  COUNT(*) FILTER (WHERE success = false) as error_count
FROM public.performance_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY metric_type, metric_name
ORDER BY avg_duration DESC;

-- Slow Queries (Last 24h, >1 second)
CREATE OR REPLACE VIEW slow_queries_24h AS
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
-- 5. Auto Cleanup (Keep Database Small & Free!)
-- =====================================================

-- Delete old error logs (keep 30 days)
CREATE OR REPLACE FUNCTION cleanup_old_error_logs()
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

-- Delete old performance logs (keep 7 days)
CREATE OR REPLACE FUNCTION cleanup_old_performance_logs()
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

-- =====================================================
-- 6. Quick Stats Functions
-- =====================================================

-- Get error count (last 24h)
CREATE OR REPLACE FUNCTION get_error_count_24h()
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM public.error_logs
    WHERE created_at > NOW() - INTERVAL '24 hours'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get average API response time (last 24h)
CREATE OR REPLACE FUNCTION get_avg_api_time_24h()
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT AVG(duration_ms)::INTEGER
    FROM public.performance_logs
    WHERE created_at > NOW() - INTERVAL '24 hours'
      AND metric_type = 'api_call'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. Initial Data
-- =====================================================

-- Insert sample log (for testing)
SELECT log_error(
  'system_initialized',
  'Monitoring system initialized successfully',
  NULL,
  NULL,
  'system',
  NULL,
  jsonb_build_object('version', '1.0.0')
);

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================

SELECT 
  'Monitoring tables created successfully!' AS status,
  (SELECT COUNT(*) FROM public.error_logs) AS error_logs_count,
  (SELECT COUNT(*) FROM public.performance_logs) AS performance_logs_count;

-- =====================================================
-- NOTES
-- =====================================================

/*
SETUP COMPLETE! ✅

Next Steps:
1. Run cleanup functions weekly (cron job)
2. Monitor database size in Supabase Dashboard
3. Adjust retention periods if needed

Estimated Storage (per month):
- 10,000 errors: ~5 MB
- 100,000 performance logs: ~20 MB
- Total: ~25 MB (0.5% of free tier!)

You can store YEARS of logs for FREE! 🎉
*/
