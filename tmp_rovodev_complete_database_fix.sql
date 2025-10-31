-- ===================================================================
-- Complete Database Fix - All Views Functions
-- ===================================================================

-- ===== 1. FIX JOB OFFERS VIEWS =====

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

-- ===== 2. FIX VET SUPPLIES VIEWS =====

-- Remove all conflicting vet supply views functions
DROP FUNCTION IF EXISTS public.increment_vet_supply_views(p_supply_id TEXT);
DROP FUNCTION IF EXISTS public.increment_vet_supply_views(p_supply_id UUID);
DROP FUNCTION IF EXISTS public.increment_vet_supply_views(TEXT);
DROP FUNCTION IF EXISTS public.increment_vet_supply_views(UUID);

-- Create simple vet supply views function (exactly like courses/books/jobs)
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

-- ===== 3. COMPREHENSIVE TEST =====

DO $$
DECLARE
    test_job_id UUID;
    test_supply_id UUID;
    job_initial_views INTEGER;
    job_final_views INTEGER;
    supply_initial_views INTEGER;
    supply_final_views INTEGER;
    test_results TEXT := '';
BEGIN
    RAISE NOTICE '🧪 === COMPREHENSIVE VIEWS SYSTEM TEST ===';
    
    -- Test Job Views
    RAISE NOTICE '📝 Testing Job Offers Views...';
    SELECT id INTO test_job_id 
    FROM public.job_offers 
    WHERE status = 'active' 
    LIMIT 1;
    
    IF test_job_id IS NOT NULL THEN
        SELECT views_count INTO job_initial_views 
        FROM public.job_offers 
        WHERE id = test_job_id;
        
        PERFORM public.increment_job_views(test_job_id);
        
        SELECT views_count INTO job_final_views 
        FROM public.job_offers 
        WHERE id = test_job_id;
        
        IF job_final_views = job_initial_views + 1 THEN
            RAISE NOTICE '✅ Job Views: SUCCESS (% → %)', job_initial_views, job_final_views;
            test_results := test_results || 'Job Views: ✅ SUCCESS | ';
        ELSE
            RAISE NOTICE '❌ Job Views: FAILED (Expected %, got %)', job_initial_views + 1, job_final_views;
            test_results := test_results || 'Job Views: ❌ FAILED | ';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No active job offers found';
        test_results := test_results || 'Job Views: ⚠️ NO DATA | ';
    END IF;
    
    -- Test Vet Supply Views
    RAISE NOTICE '🏥 Testing Vet Supplies Views...';
    SELECT id INTO test_supply_id 
    FROM public.vet_supplies 
    WHERE status = 'active' 
    LIMIT 1;
    
    IF test_supply_id IS NOT NULL THEN
        SELECT views_count INTO supply_initial_views 
        FROM public.vet_supplies 
        WHERE id = test_supply_id;
        
        PERFORM public.increment_vet_supply_views(test_supply_id);
        
        SELECT views_count INTO supply_final_views 
        FROM public.vet_supplies 
        WHERE id = test_supply_id;
        
        IF supply_final_views = supply_initial_views + 1 THEN
            RAISE NOTICE '✅ Supply Views: SUCCESS (% → %)', supply_initial_views, supply_final_views;
            test_results := test_results || 'Supply Views: ✅ SUCCESS';
        ELSE
            RAISE NOTICE '❌ Supply Views: FAILED (Expected %, got %)', supply_initial_views + 1, supply_final_views;
            test_results := test_results || 'Supply Views: ❌ FAILED';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No active vet supplies found';
        test_results := test_results || 'Supply Views: ⚠️ NO DATA';
    END IF;
    
    RAISE NOTICE '🎯 === TEST SUMMARY ===';
    RAISE NOTICE '%', test_results;
    RAISE NOTICE '🎉 Database Views System Test Complete!';
END;
$$;

-- ===== 4. FINAL STATUS =====

SELECT 
    '🎯 Complete Database Views System Fixed' as status,
    'Jobs: increment_job_views(UUID) - triggers on click' as job_behavior,
    'Supplies: increment_vet_supply_views(UUID) - triggers on card visibility' as supply_behavior,
    'Both functions work exactly like courses/books pattern' as compatibility,
    'No more function overload conflicts' as solution;