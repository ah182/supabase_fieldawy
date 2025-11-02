-- إنشاء نظام تتبع عمليات البحث الحقيقية
-- Create real search tracking system

-- جدول تتبع عمليات البحث
-- Search tracking table
CREATE TABLE IF NOT EXISTS search_tracking (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    search_term TEXT NOT NULL,
    search_type VARCHAR(50) DEFAULT 'general', -- 'products', 'categories', 'distributors', 'general'
    search_location TEXT, -- المحافظة أو الموقع
    result_count INTEGER DEFAULT 0,
    clicked_result_id UUID, -- ID المنتج أو النتيجة التي تم النقر عليها
    session_id TEXT, -- جلسة البحث
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- فهارس لتحسين الأداء
-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_search_tracking_user_id ON search_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_search_tracking_search_term ON search_tracking(search_term);
CREATE INDEX IF NOT EXISTS idx_search_tracking_created_at ON search_tracking(created_at);
CREATE INDEX IF NOT EXISTS idx_search_tracking_search_type ON search_tracking(search_type);

-- فهرس مركب للبحث السريع
-- Composite index for fast searches
CREATE INDEX IF NOT EXISTS idx_search_tracking_term_date ON search_tracking(search_term, created_at DESC);

-- دالة لتسجيل عملية بحث جديدة
-- Function to log a new search
CREATE OR REPLACE FUNCTION log_search_activity(
    p_user_id UUID,
    p_search_term TEXT,
    p_search_type VARCHAR(50) DEFAULT 'general',
    p_search_location TEXT DEFAULT NULL,
    p_result_count INTEGER DEFAULT 0,
    p_session_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    search_id UUID;
BEGIN
    -- تسجيل عملية البحث
    INSERT INTO search_tracking (
        user_id, 
        search_term, 
        search_type,
        search_location,
        result_count,
        session_id
    )
    VALUES (
        p_user_id, 
        LOWER(TRIM(p_search_term)), 
        p_search_type,
        p_search_location,
        p_result_count,
        p_session_id
    )
    RETURNING id INTO search_id;
    
    RETURN search_id;
END;
$$;

-- دالة لتحديث نتيجة البحث عند النقر
-- Function to update search result when clicked
CREATE OR REPLACE FUNCTION update_search_click(
    p_search_id UUID,
    p_clicked_result_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE search_tracking 
    SET 
        clicked_result_id = p_clicked_result_id,
        updated_at = NOW()
    WHERE id = p_search_id;
    
    RETURN FOUND;
END;
$$;

-- دالة للحصول على أكثر الكلمات بحثاً
-- Function to get most searched terms
CREATE OR REPLACE FUNCTION get_top_search_terms(
    p_limit INTEGER DEFAULT 20,
    p_days INTEGER DEFAULT 7,
    p_search_type VARCHAR(50) DEFAULT NULL
)
RETURNS TABLE (
    search_term TEXT,
    search_count BIGINT,
    unique_users BIGINT,
    avg_result_count NUMERIC,
    click_rate NUMERIC,
    trend_direction TEXT,
    growth_percentage NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    date_threshold TIMESTAMP WITH TIME ZONE;
    prev_period_start TIMESTAMP WITH TIME ZONE;
BEGIN
    -- حساب تاريخ البداية للفترة المطلوبة
    date_threshold := NOW() - (p_days || ' days')::INTERVAL;
    prev_period_start := date_threshold - (p_days || ' days')::INTERVAL;
    
    RETURN QUERY
    WITH current_period AS (
        SELECT 
            s.search_term,
            COUNT(*) as current_searches,
            COUNT(DISTINCT s.user_id) as current_users,
            AVG(s.result_count) as avg_results,
            COUNT(s.clicked_result_id)::NUMERIC / COUNT(*)::NUMERIC * 100 as click_percentage
        FROM search_tracking s
        WHERE s.created_at >= date_threshold
          AND (p_search_type IS NULL OR s.search_type = p_search_type)
        GROUP BY s.search_term
    ),
    previous_period AS (
        SELECT 
            s.search_term,
            COUNT(*) as prev_searches
        FROM search_tracking s
        WHERE s.created_at >= prev_period_start 
          AND s.created_at < date_threshold
          AND (p_search_type IS NULL OR s.search_type = p_search_type)
        GROUP BY s.search_term
    )
    SELECT 
        cp.search_term,
        cp.current_searches,
        cp.current_users,
        ROUND(cp.avg_results, 1),
        ROUND(cp.click_percentage, 1),
        CASE 
            WHEN pp.prev_searches IS NULL THEN 'new'
            WHEN cp.current_searches > pp.prev_searches THEN 'up'
            WHEN cp.current_searches < pp.prev_searches THEN 'down'
            ELSE 'stable'
        END as trend_dir,
        CASE 
            WHEN pp.prev_searches IS NULL OR pp.prev_searches = 0 THEN 100.0
            ELSE ROUND(((cp.current_searches - pp.prev_searches)::NUMERIC / pp.prev_searches::NUMERIC) * 100, 1)
        END as growth_perc
    FROM current_period cp
    LEFT JOIN previous_period pp ON cp.search_term = pp.search_term
    WHERE cp.current_searches >= 2  -- فقط الكلمات التي تم البحث عنها أكثر من مرة
    ORDER BY cp.current_searches DESC, cp.current_users DESC
    LIMIT p_limit;
END;
$$;

-- دالة للحصول على الترندات الجغرافية للبحث
-- Function to get geographic search trends
CREATE OR REPLACE FUNCTION get_search_trends_by_location(
    p_limit INTEGER DEFAULT 10,
    p_days INTEGER DEFAULT 7
)
RETURNS TABLE (
    search_location TEXT,
    total_searches BIGINT,
    unique_terms BIGINT,
    top_term TEXT,
    top_term_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    date_threshold TIMESTAMP WITH TIME ZONE;
BEGIN
    date_threshold := NOW() - (p_days || ' days')::INTERVAL;
    
    RETURN QUERY
    WITH location_stats AS (
        SELECT 
            s.search_location,
            COUNT(*) as total_count,
            COUNT(DISTINCT s.search_term) as unique_terms_count,
            s.search_term,
            COUNT(*) OVER (PARTITION BY s.search_location, s.search_term) as term_count,
            ROW_NUMBER() OVER (PARTITION BY s.search_location ORDER BY COUNT(*) DESC) as rn
        FROM search_tracking s
        WHERE s.created_at >= date_threshold
          AND s.search_location IS NOT NULL
          AND s.search_location != ''
        GROUP BY s.search_location, s.search_term
    )
    SELECT 
        ls.search_location,
        MAX(ls.total_count),
        MAX(ls.unique_terms_count),
        MAX(CASE WHEN ls.rn = 1 THEN ls.search_term END),
        MAX(CASE WHEN ls.rn = 1 THEN ls.term_count END)
    FROM location_stats ls
    GROUP BY ls.search_location
    ORDER BY MAX(ls.total_count) DESC
    LIMIT p_limit;
END;
$$;

-- دالة للحصول على اتجاهات البحث بالوقت
-- Function to get search trends over time
CREATE OR REPLACE FUNCTION get_search_trends_hourly(
    p_search_term TEXT DEFAULT NULL,
    p_hours INTEGER DEFAULT 24
)
RETURNS TABLE (
    hour_bucket TIMESTAMP WITH TIME ZONE,
    search_count BIGINT,
    unique_users BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    start_time TIMESTAMP WITH TIME ZONE;
BEGIN
    start_time := NOW() - (p_hours || ' hours')::INTERVAL;
    
    RETURN QUERY
    SELECT 
        date_trunc('hour', s.created_at) as hour_bucket,
        COUNT(*) as search_count,
        COUNT(DISTINCT s.user_id) as unique_users
    FROM search_tracking s
    WHERE s.created_at >= start_time
      AND (p_search_term IS NULL OR s.search_term ILIKE '%' || p_search_term || '%')
    GROUP BY date_trunc('hour', s.created_at)
    ORDER BY hour_bucket;
END;
$$;

-- إعداد Row Level Security (RLS)
-- Setup Row Level Security
ALTER TABLE search_tracking ENABLE ROW LEVEL SECURITY;

-- سياسة للقراءة: المستخدمون يمكنهم رؤية عمليات البحث الخاصة بهم فقط
-- Read policy: Users can only see their own searches
CREATE POLICY "Users can view own search history" ON search_tracking
    FOR SELECT USING (auth.uid() = user_id);

-- سياسة للإدراج: المستخدمون يمكنهم إدراج عمليات البحث الخاصة بهم فقط
-- Insert policy: Users can only insert their own searches
CREATE POLICY "Users can insert own searches" ON search_tracking
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- سياسة للتحديث: المستخدمون يمكنهم تحديث عمليات البحث الخاصة بهم فقط
-- Update policy: Users can only update their own searches
CREATE POLICY "Users can update own searches" ON search_tracking
    FOR UPDATE USING (auth.uid() = user_id);

-- منح صلاحيات للمستخدمين المصادق عليهم
-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE ON search_tracking TO authenticated;
GRANT USAGE ON SEQUENCE search_tracking_id_seq TO authenticated;

-- منح صلاحيات تنفيذ الدوال
-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION log_search_activity TO authenticated;
GRANT EXECUTE ON FUNCTION update_search_click TO authenticated;
GRANT EXECUTE ON FUNCTION get_top_search_terms TO authenticated;
GRANT EXECUTE ON FUNCTION get_search_trends_by_location TO authenticated;
GRANT EXECUTE ON FUNCTION get_search_trends_hourly TO authenticated;

-- إنشاء مشغل للتحديث التلقائي لوقت التعديل
-- Create trigger for automatic updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_search_tracking_updated_at 
    BEFORE UPDATE ON search_tracking 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- إدراج بعض البيانات التجريبية للاختبار
-- Insert some test data
INSERT INTO search_tracking (user_id, search_term, search_type, search_location, result_count, session_id)
SELECT 
    auth.uid(),
    term,
    'products',
    'القاهرة',
    floor(random() * 50 + 5)::integer,
    'test_session_' || generate_random_uuid()::text
FROM (
    VALUES 
    ('مضاد حيوي'),
    ('فيتامينات'),
    ('أدوية قطط'),
    ('حقن بيطرية'),
    ('علاج التهابات'),
    ('مسكنات ألم'),
    ('أدوية كلاب'),
    ('مطهرات جروح'),
    ('أموكسيسيلين'),
    ('إنروفلوكساسين'),
    ('دوكسيسيكلين'),
    ('سيفالكسين'),
    ('أزيثروميسين'),
    ('بنسلين'),
    ('جنتامايسين'),
    ('كلورامفينيكول'),
    ('سلفاديازين'),
    ('تايلوسين'),
    ('لينكومايسين'),
    ('نيومايسين')
) AS search_terms(term)
WHERE auth.uid() IS NOT NULL;

-- إضافة تعليق على الجدول
COMMENT ON TABLE search_tracking IS 'جدول تتبع عمليات البحث للمستخدمين لتحليل الاتجاهات والترندات';
COMMENT ON FUNCTION get_top_search_terms IS 'الحصول على أكثر المصطلحات بحثاً مع الإحصائيات والترندات';
COMMENT ON FUNCTION get_search_trends_by_location IS 'الحصول على اتجاهات البحث حسب الموقع الجغرافي';
COMMENT ON FUNCTION get_search_trends_hourly IS 'الحصول على اتجاهات البحث بالساعة';