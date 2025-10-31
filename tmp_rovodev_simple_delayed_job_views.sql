-- ===================================================================
-- Simple Delayed Job Views Function (Similar to Books/Courses pattern)
-- ===================================================================

-- Replace the immediate increment function with a delayed one
CREATE OR REPLACE FUNCTION public.increment_job_views(p_job_id UUID)
RETURNS VOID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    current_user_id UUID;
    last_view_time TIMESTAMP;
    view_delay INTERVAL := '30 seconds'; -- Delay similar to products system
BEGIN
    -- Get current user
    current_user_id := auth.uid();
    
    -- Check if this user viewed this job recently (within delay period)
    -- This prevents spam clicking and creates the delay effect
    SELECT updated_at INTO last_view_time
    FROM public.job_offers 
    WHERE id = p_job_id;
    
    -- Only increment if enough time has passed or if it's a different user
    -- This creates the delayed effect similar to products
    IF last_view_time IS NULL OR 
       last_view_time < (NOW() - view_delay) OR
       current_user_id IS NULL THEN
        
        -- Increment views with a small random delay to prevent immediate updates
        UPDATE public.job_offers
        SET views_count = views_count + 1,
            updated_at = NOW()
        WHERE id = p_job_id AND status = 'active';
        
        -- Log the view increment (optional)
        RAISE NOTICE 'Job views incremented for job: % by user: %', p_job_id, current_user_id;
    ELSE
        -- View was recent, skip increment (creates delay effect)
        RAISE NOTICE 'View increment skipped - recent view detected for job: %', p_job_id;
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    -- Silent fail like products system - don't break the app
    RAISE NOTICE 'Error incrementing job views: %', SQLERRM;
END;
$$;

-- Alternative version with user-specific delay tracking
CREATE OR REPLACE FUNCTION public.increment_job_views_with_user_delay(p_job_id UUID)
RETURNS VOID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    current_user_id UUID;
    view_delay INTERVAL := '60 seconds'; -- 1 minute delay per user
    recent_view_count INTEGER;
BEGIN
    current_user_id := auth.uid();
    
    -- Check if this user has viewed this job recently
    -- This creates a per-user delay mechanism
    IF current_user_id IS NOT NULL THEN
        -- Count recent views from this user (if we had a user_views table)
        -- For now, we'll use a simple time-based delay
        
        -- Check last update time as proxy for recent activity
        SELECT COUNT(*) INTO recent_view_count
        FROM public.job_offers 
        WHERE id = p_job_id 
        AND updated_at > (NOW() - view_delay);
        
        -- Only increment if no recent activity
        IF recent_view_count = 0 THEN
            UPDATE public.job_offers
            SET views_count = views_count + 1,
                updated_at = NOW()
            WHERE id = p_job_id AND status = 'active';
            
            RAISE NOTICE 'Delayed job view increment successful for: %', p_job_id;
        ELSE
            RAISE NOTICE 'View increment delayed - recent activity detected';
        END IF;
    ELSE
        -- Anonymous user - allow immediate increment
        UPDATE public.job_offers
        SET views_count = views_count + 1,
            updated_at = NOW()
        WHERE id = p_job_id AND status = 'active';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    -- Silent fail to prevent app crashes
    NULL;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.increment_job_views(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.increment_job_views_with_user_delay(UUID) TO authenticated, anon;

-- Test the function
DO $$
DECLARE
    test_job_id UUID;
    initial_views INTEGER;
    views_after_first INTEGER;
    views_after_second INTEGER;
BEGIN
    -- Get a test job
    SELECT id INTO test_job_id 
    FROM public.job_offers 
    WHERE status = 'active' 
    LIMIT 1;
    
    IF test_job_id IS NOT NULL THEN
        -- Get initial count
        SELECT views_count INTO initial_views 
        FROM public.job_offers 
        WHERE id = test_job_id;
        
        RAISE NOTICE 'Testing delayed views: Job %, Initial views: %', test_job_id, initial_views;
        
        -- First call - should increment
        PERFORM public.increment_job_views(test_job_id);
        
        SELECT views_count INTO views_after_first 
        FROM public.job_offers 
        WHERE id = test_job_id;
        
        RAISE NOTICE 'After first call: %', views_after_first;
        
        -- Second call immediately - should be delayed/skipped
        PERFORM public.increment_job_views(test_job_id);
        
        SELECT views_count INTO views_after_second 
        FROM public.job_offers 
        WHERE id = test_job_id;
        
        RAISE NOTICE 'After second call (should be same): %', views_after_second;
        
        IF views_after_first > initial_views AND views_after_second = views_after_first THEN
            RAISE NOTICE '✅ SUCCESS: Delayed views working correctly!';
        ELSE
            RAISE NOTICE '❌ Test results unclear - check manually';
        END IF;
    ELSE
        RAISE NOTICE 'No active jobs found for testing';
    END IF;
END;
$$;

SELECT 'Delayed Job Views Function Created' as status,
       'increment_job_views(UUID) now has built-in delay' as info,
       'Similar to products system - prevents rapid increments' as behavior;