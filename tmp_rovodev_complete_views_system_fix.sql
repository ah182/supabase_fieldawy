-- ===================================================================
-- Complete Views System Fix
-- 1. Fix Job Views to work on click (like courses/books)
-- 2. Create Vet Supplies Views to work on card visibility
-- ===================================================================

-- ===== 1. JOB OFFERS VIEWS (ON CLICK) =====

-- Remove all conflicting job views functions
DROP FUNCTION IF EXISTS public.increment_job_views(p_job_id TEXT);
DROP FUNCTION IF EXISTS public.increment_job_views(p_job_id UUID);
DROP FUNCTION IF EXISTS public.increment_job_views(TEXT);
DROP FUNCTION IF EXISTS public.increment_job_views(UUID);
DROP FUNCTION IF EXISTS public.increment_job_views_uuid CASCADE;
DROP FUNCTION IF EXISTS public.increment_job_views_with_user_delay CASCADE;
DROP FUNCTION IF EXISTS public.queue_job_view CASCADE;
DROP FUNCTION IF EXISTS public.process_job_views_queue CASCADE;

-- Create simple job views function (exactly like courses/books)
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

-- Grant permissions for job views
GRANT EXECUTE ON FUNCTION public.increment_job_views(UUID) TO authenticated, anon;

-- ===== 2. VET SUPPLIES VIEWS (ON CARD VISIBILITY) =====

-- Create vet supplies views function (exactly like courses/books/jobs)
CREATE OR REPLACE FUNCTION public.increment_vet_supply_views(p_supply_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.vet_supplies
    SET views_count = views_count + 1
    WHERE id = p_supply_id;
END;
$$;

-- Grant permissions for vet supply views
GRANT EXECUTE ON FUNCTION public.increment_vet_supply_views(UUID) TO authenticated, anon;

-- ===== 3. TEST BOTH SYSTEMS =====

DO $$
DECLARE
    test_job_id UUID;
    test_supply_id UUID;
    job_initial_views INTEGER;
    job_final_views INTEGER;
    supply_initial_views INTEGER;
    supply_final_views INTEGER;
BEGIN
    RAISE NOTICE '🧪 Testing Complete Views System...';
    
    -- Test Job Views
    SELECT id INTO test_job_id 
    FROM public.job_offers 
    WHERE status = 'active' 
    LIMIT 1;
    
    IF test_job_id IS NOT NULL THEN
        SELECT views_count INTO job_initial_views 
        FROM public.job_offers 
        WHERE id = test_job_id;
        
        RAISE NOTICE '📝 Job Test: ID %, Initial views: %', test_job_id, job_initial_views;
        
        PERFORM public.increment_job_views(test_job_id);
        
        SELECT views_count INTO job_final_views 
        FROM public.job_offers 
        WHERE id = test_job_id;
        
        IF job_final_views = job_initial_views + 1 THEN
            RAISE NOTICE '✅ Job Views: SUCCESS (% → %)', job_initial_views, job_final_views;
        ELSE
            RAISE NOTICE '❌ Job Views: FAILED (Expected %, got %)', job_initial_views + 1, job_final_views;
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No active job offers found for testing';
    END IF;
    
    -- Test Vet Supply Views
    SELECT id INTO test_supply_id 
    FROM public.vet_supplies 
    WHERE status = 'active' 
    LIMIT 1;
    
    IF test_supply_id IS NOT NULL THEN
        SELECT views_count INTO supply_initial_views 
        FROM public.vet_supplies 
        WHERE id = test_supply_id;
        
        RAISE NOTICE '🏥 Supply Test: ID %, Initial views: %', test_supply_id, supply_initial_views;
        
        PERFORM public.increment_vet_supply_views(test_supply_id);
        
        SELECT views_count INTO supply_final_views 
        FROM public.vet_supplies 
        WHERE id = test_supply_id;
        
        IF supply_final_views = supply_initial_views + 1 THEN
            RAISE NOTICE '✅ Supply Views: SUCCESS (% → %)', supply_initial_views, supply_final_views;
        ELSE
            RAISE NOTICE '❌ Supply Views: FAILED (Expected %, got %)', supply_initial_views + 1, supply_final_views;
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No active vet supplies found for testing';
    END IF;
    
    RAISE NOTICE '🎉 Views System Test Complete!';
END;
$$;

-- ===== 4. SHOW STATUS =====

SELECT 
    '✅ Complete Views System Ready' as status,
    'Jobs: increment_job_views(UUID) - triggers on click' as job_behavior,
    'Supplies: increment_vet_supply_views(UUID) - triggers on card visibility' as supply_behavior,
    'Both functions work exactly like courses/books pattern' as compatibility;