-- ===================================================================
-- Fix Job Views System to Work Exactly Like Courses/Books
-- ===================================================================

-- Step 1: Remove all conflicting functions to fix the overload error
DROP FUNCTION IF EXISTS public.increment_job_views(p_job_id TEXT);
DROP FUNCTION IF EXISTS public.increment_job_views(p_job_id UUID);
DROP FUNCTION IF EXISTS public.increment_job_views(TEXT);
DROP FUNCTION IF EXISTS public.increment_job_views(UUID);
DROP FUNCTION IF EXISTS public.increment_job_views_uuid CASCADE;
DROP FUNCTION IF EXISTS public.increment_job_views_with_user_delay CASCADE;
DROP FUNCTION IF EXISTS public.queue_job_view CASCADE;
DROP FUNCTION IF EXISTS public.process_job_views_queue CASCADE;

-- Step 2: Create the EXACT same function as courses/books
-- This is identical to increment_course_views and increment_book_views
CREATE OR REPLACE FUNCTION public.increment_job_views(p_job_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.job_offers
    SET views_count = views_count + 1
    WHERE id = p_job_id;
END;
$$;

-- Step 3: Grant the same permissions as courses/books
GRANT EXECUTE ON FUNCTION public.increment_job_views(UUID) TO authenticated, anon;

-- Step 4: Test the function to ensure it works
DO $$
DECLARE
    test_job_id UUID;
    initial_views INTEGER;
    final_views INTEGER;
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
        
        RAISE NOTICE 'Testing job views (like courses): Job %, Initial views: %', test_job_id, initial_views;
        
        -- Increment views
        PERFORM public.increment_job_views(test_job_id);
        
        -- Get final count
        SELECT views_count INTO final_views 
        FROM public.job_offers 
        WHERE id = test_job_id;
        
        RAISE NOTICE 'After increment: %, Change: %', final_views, (final_views - initial_views);
        
        IF final_views = initial_views + 1 THEN
            RAISE NOTICE '✅ SUCCESS: Job views working exactly like courses/books!';
        ELSE
            RAISE NOTICE '❌ FAILED: Expected %, got %', initial_views + 1, final_views;
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No active job offers found for testing';
        
        -- Create a test job for testing
        INSERT INTO public.job_offers (id, user_id, title, description, phone, status, views_count)
        VALUES (gen_random_uuid(), auth.uid(), 'Test Job', 'Test Description', '123456789', 'active', 0)
        RETURNING id INTO test_job_id;
        
        RAISE NOTICE 'Created test job: %', test_job_id;
        
        -- Test with new job
        PERFORM public.increment_job_views(test_job_id);
        
        SELECT views_count INTO final_views 
        FROM public.job_offers 
        WHERE id = test_job_id;
        
        IF final_views = 1 THEN
            RAISE NOTICE '✅ SUCCESS: Job views working with test job!';
        ELSE
            RAISE NOTICE '❌ FAILED: Expected 1, got %', final_views;
        END IF;
        
        -- Clean up test job
        DELETE FROM public.job_offers WHERE id = test_job_id;
        RAISE NOTICE 'Test job cleaned up';
    END IF;
END;
$$;

-- Step 5: Show status
SELECT 
    'Job Views System Fixed' as status,
    'increment_job_views(UUID) now works exactly like courses/books' as description,
    'No more function overload conflicts' as solution,
    'Views increment immediately on dialog open' as behavior;