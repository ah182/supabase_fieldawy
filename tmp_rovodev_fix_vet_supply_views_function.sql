-- ===================================================================
-- Fix Vet Supply Views Function - Remove Function Overload Conflict
-- ===================================================================

-- Remove all conflicting vet supply views functions
DROP FUNCTION IF EXISTS public.increment_vet_supply_views(p_supply_id TEXT);
DROP FUNCTION IF EXISTS public.increment_vet_supply_views(p_supply_id UUID);
DROP FUNCTION IF EXISTS public.increment_vet_supply_views(TEXT);
DROP FUNCTION IF EXISTS public.increment_vet_supply_views(UUID);

-- Create ONE SINGLE vet supply views function (exactly like jobs/courses/books)
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.increment_vet_supply_views(UUID) TO authenticated, anon;

-- Test the function
DO $$
DECLARE
    test_supply_id UUID;
    initial_views INTEGER;
    final_views INTEGER;
BEGIN
    -- Get a test vet supply
    SELECT id INTO test_supply_id 
    FROM public.vet_supplies 
    WHERE status = 'active' 
    LIMIT 1;
    
    IF test_supply_id IS NOT NULL THEN
        -- Get initial count
        SELECT views_count INTO initial_views 
        FROM public.vet_supplies 
        WHERE id = test_supply_id;
        
        RAISE NOTICE 'Testing vet supply views: Supply %, Initial views: %', test_supply_id, initial_views;
        
        -- Increment views
        PERFORM public.increment_vet_supply_views(test_supply_id);
        
        -- Get final count
        SELECT views_count INTO final_views 
        FROM public.vet_supplies 
        WHERE id = test_supply_id;
        
        RAISE NOTICE 'After increment: %, Change: %', final_views, (final_views - initial_views);
        
        IF final_views = initial_views + 1 THEN
            RAISE NOTICE '✅ SUCCESS: Vet supply views working correctly!';
        ELSE
            RAISE NOTICE '❌ FAILED: Expected %, got %', initial_views + 1, final_views;
        END IF;
    ELSE
        RAISE NOTICE '⚠️ No active vet supplies found for testing';
        
        -- Create a test supply for testing if none exist
        INSERT INTO public.vet_supplies (id, user_id, name, description, price, phone, status, views_count)
        VALUES (gen_random_uuid(), auth.uid(), 'Test Supply', 'Test Description', 100.0, '123456789', 'active', 0)
        RETURNING id INTO test_supply_id;
        
        RAISE NOTICE 'Created test supply: %', test_supply_id;
        
        -- Test with new supply
        PERFORM public.increment_vet_supply_views(test_supply_id);
        
        SELECT views_count INTO final_views 
        FROM public.vet_supplies 
        WHERE id = test_supply_id;
        
        IF final_views = 1 THEN
            RAISE NOTICE '✅ SUCCESS: Vet supply views working with test supply!';
        ELSE
            RAISE NOTICE '❌ FAILED: Expected 1, got %', final_views;
        END IF;
        
        -- Clean up test supply
        DELETE FROM public.vet_supplies WHERE id = test_supply_id;
        RAISE NOTICE 'Test supply cleaned up';
    END IF;
END;
$$;

-- Show status
SELECT 
    'Vet Supply Views Function Fixed' as status,
    'increment_vet_supply_views(UUID) now works exactly like jobs/courses/books' as description,
    'No more function overload conflicts' as solution,
    'Views increment when card becomes visible on screen' as behavior;