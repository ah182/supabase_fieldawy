-- ===================================================================
-- Delayed Job Views Function - Similar to Products Views System
-- ===================================================================

-- Drop existing immediate increment function
DROP FUNCTION IF EXISTS public.increment_job_views(UUID);
DROP FUNCTION IF EXISTS public.increment_job_views(p_job_id UUID);

-- Create a table to track delayed view increments
CREATE TABLE IF NOT EXISTS public.job_views_queue (
    id SERIAL PRIMARY KEY,
    job_id UUID NOT NULL,
    user_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed BOOLEAN DEFAULT FALSE
);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_job_views_queue_job_id ON public.job_views_queue(job_id);
CREATE INDEX IF NOT EXISTS idx_job_views_queue_processed ON public.job_views_queue(processed);

-- Function to queue a view increment (called immediately)
CREATE OR REPLACE FUNCTION public.queue_job_view(p_job_id UUID)
RETURNS VOID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- Add to queue instead of immediate increment
    INSERT INTO public.job_views_queue (job_id, user_id)
    VALUES (p_job_id, auth.uid());
END;
$$;

-- Function to process queued views (runs periodically via cron or trigger)
CREATE OR REPLACE FUNCTION public.process_job_views_queue()
RETURNS INTEGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    processed_count INTEGER := 0;
    view_record RECORD;
BEGIN
    -- Process unprocessed view increments
    FOR view_record IN 
        SELECT job_id, COUNT(*) as view_count
        FROM public.job_views_queue 
        WHERE processed = FALSE 
        GROUP BY job_id
    LOOP
        -- Increment the actual views count
        UPDATE public.job_offers
        SET views_count = views_count + view_record.view_count
        WHERE id = view_record.job_id AND status = 'active';
        
        -- Mark as processed
        UPDATE public.job_views_queue
        SET processed = TRUE
        WHERE job_id = view_record.job_id AND processed = FALSE;
        
        processed_count := processed_count + view_record.view_count;
    END LOOP;
    
    -- Clean up old processed records (older than 1 hour)
    DELETE FROM public.job_views_queue 
    WHERE processed = TRUE 
    AND created_at < NOW() - INTERVAL '1 hour';
    
    RETURN processed_count;
END;
$$;

-- Create the main function that will be called from the app (replaces increment_job_views)
CREATE OR REPLACE FUNCTION public.increment_job_views(p_job_id UUID)
RETURNS VOID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- Just queue the view, don't increment immediately
    PERFORM public.queue_job_view(p_job_id);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.queue_job_view(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.process_job_views_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_job_views(UUID) TO authenticated, anon;

-- Grant table permissions
GRANT INSERT, SELECT ON public.job_views_queue TO authenticated, anon;
GRANT UPDATE, DELETE ON public.job_views_queue TO authenticated;

-- Create a trigger to process views every few seconds (alternative to cron)
-- This will process views with a small delay
CREATE OR REPLACE FUNCTION public.trigger_process_job_views()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only process if there are enough queued views or enough time has passed
    IF (SELECT COUNT(*) FROM public.job_views_queue WHERE processed = FALSE) >= 3 
       OR (SELECT MIN(created_at) FROM public.job_views_queue WHERE processed = FALSE) < NOW() - INTERVAL '30 seconds'
    THEN
        PERFORM public.process_job_views_queue();
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create trigger that fires after insert to job_views_queue
DROP TRIGGER IF EXISTS trigger_delayed_job_views ON public.job_views_queue;
CREATE TRIGGER trigger_delayed_job_views
    AFTER INSERT ON public.job_views_queue
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_process_job_views();

-- Test the system
DO $$
DECLARE
    test_job_id UUID;
    initial_views INTEGER;
    final_views INTEGER;
BEGIN
    -- Get a real job ID for testing
    SELECT id INTO test_job_id 
    FROM public.job_offers 
    WHERE status = 'active' 
    LIMIT 1;
    
    IF test_job_id IS NOT NULL THEN
        -- Get initial views
        SELECT views_count INTO initial_views 
        FROM public.job_offers 
        WHERE id = test_job_id;
        
        RAISE NOTICE 'Testing delayed job views system...';
        RAISE NOTICE 'Job ID: %, Initial views: %', test_job_id, initial_views;
        
        -- Queue some views
        PERFORM public.increment_job_views(test_job_id);
        PERFORM public.increment_job_views(test_job_id);
        PERFORM public.increment_job_views(test_job_id);
        
        RAISE NOTICE 'Views queued. Processing queue...';
        
        -- Force process the queue
        PERFORM public.process_job_views_queue();
        
        -- Check final views
        SELECT views_count INTO final_views 
        FROM public.job_offers 
        WHERE id = test_job_id;
        
        RAISE NOTICE 'Final views: %, Increment: %', final_views, (final_views - initial_views);
        
        IF final_views = initial_views + 3 THEN
            RAISE NOTICE '✅ SUCCESS: Delayed job views system working correctly!';
        ELSE
            RAISE NOTICE '❌ FAILED: Expected %, got %', initial_views + 3, final_views;
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No active job offers found for testing';
    END IF;
END;
$$;

-- Show status
SELECT 
    'Delayed Job Views System Ready' as status,
    'increment_job_views(UUID) - queues views for delayed processing' as main_function,
    'process_job_views_queue() - processes queued views' as processor_function,
    'Automatic processing via trigger after 3 views or 30 seconds' as auto_processing;