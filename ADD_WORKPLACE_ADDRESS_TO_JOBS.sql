-- ====================================
-- Add Workplace Address to Job Offers (FIXED & RELAXED VALIDATION)
-- Description: Adds 'workplace_address' column and updates functions with relaxed phone validation
-- ====================================

-- 1. Add column to table (safely)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'job_offers' AND column_name = 'workplace_address') THEN
        ALTER TABLE public.job_offers 
        ADD COLUMN workplace_address TEXT NOT NULL DEFAULT 'العنوان غير محدد';
        
        COMMENT ON COLUMN public.job_offers.workplace_address IS 'Physical address of the workplace';
    END IF;
END $$;

-- 2. Drop existing functions (both old and new signatures to ensure clean update)
DROP FUNCTION IF EXISTS public.get_all_job_offers();
DROP FUNCTION IF EXISTS public.get_my_job_offers(UUID);

-- Drop old signatures
DROP FUNCTION IF EXISTS public.create_job_offer(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.update_job_offer(UUID, TEXT, TEXT, TEXT);

-- Drop new signatures (if they exist from previous failed/partial runs)
DROP FUNCTION IF EXISTS public.create_job_offer(TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.update_job_offer(UUID, TEXT, TEXT, TEXT, TEXT);

-- 3. Re-create get_all_job_offers function
CREATE OR REPLACE FUNCTION public.get_all_job_offers()
RETURNS TABLE (
    id UUID,
    user_id UUID,
    user_name TEXT,
    title TEXT,
    description TEXT,
    phone TEXT,
    workplace_address TEXT,
    status TEXT,
    views_count INTEGER,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        jo.id,
        jo.user_id,
        COALESCE(u.display_name, u.email, 'مستخدم') as user_name,
        jo.title,
        jo.description,
        jo.phone,
        jo.workplace_address,
        jo.status,
        jo.views_count,
        jo.created_at,
        jo.updated_at
    FROM public.job_offers jo
    LEFT JOIN public.users u ON jo.user_id = u.id
    WHERE jo.status = 'active'
    ORDER BY jo.created_at DESC;
END;
$$;

-- 4. Re-create get_my_job_offers function
CREATE OR REPLACE FUNCTION public.get_my_job_offers(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    title TEXT,
    description TEXT,
    phone TEXT,
    workplace_address TEXT,
    status TEXT,
    views_count INTEGER,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check if the requesting user is the same as p_user_id
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Unauthorized access';
    END IF;

    RETURN QUERY
    SELECT 
        jo.id,
        jo.user_id,
        jo.title,
        jo.description,
        jo.phone,
        jo.workplace_address,
        jo.status,
        jo.views_count,
        jo.created_at,
        jo.updated_at
    FROM public.job_offers jo
    WHERE jo.user_id = p_user_id
    ORDER BY jo.created_at DESC;
END;
$$;

-- 5. Re-create create_job_offer function (RELAXED VALIDATION)
CREATE OR REPLACE FUNCTION public.create_job_offer(
    p_title TEXT,
    p_description TEXT,
    p_phone TEXT,
    p_workplace_address TEXT
)
RETURNS UUID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_job_id UUID;
BEGIN
    -- Check if user is authenticated
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    -- Validate inputs
    IF char_length(p_title) < 10 OR char_length(p_title) > 200 THEN
        RAISE EXCEPTION 'Title must be between 10 and 200 characters';
    END IF;

    IF char_length(p_description) < 50 OR char_length(p_description) > 2000 THEN
        RAISE EXCEPTION 'Description must be between 50 and 2000 characters';
    END IF;

    IF p_workplace_address IS NULL OR char_length(p_workplace_address) < 3 THEN
        RAISE EXCEPTION 'Workplace address is required';
    END IF;

    -- PHONE VALIDATION REMOVED to support international numbers
    -- IF NOT (p_phone ~ '^01[0-9]{9}$') THEN
    --    RAISE EXCEPTION 'Phone number must be in Egyptian format (01XXXXXXXXX)';
    -- END IF;

    -- Insert the job offer
    INSERT INTO public.job_offers (user_id, title, description, phone, workplace_address)
    VALUES (auth.uid(), p_title, p_description, p_phone, p_workplace_address)
    RETURNING id INTO v_job_id;

    RETURN v_job_id;
END;
$$;

-- 6. Re-create update_job_offer function (RELAXED VALIDATION)
CREATE OR REPLACE FUNCTION public.update_job_offer(
    p_job_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_phone TEXT,
    p_workplace_address TEXT
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check if user is authenticated
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    -- Validate inputs
    IF char_length(p_title) < 10 OR char_length(p_title) > 200 THEN
        RAISE EXCEPTION 'Title must be between 10 and 200 characters';
    END IF;

    IF char_length(p_description) < 50 OR char_length(p_description) > 2000 THEN
        RAISE EXCEPTION 'Description must be between 50 and 2000 characters';
    END IF;

    IF p_workplace_address IS NULL OR char_length(p_workplace_address) < 3 THEN
        RAISE EXCEPTION 'Workplace address is required';
    END IF;

    -- PHONE VALIDATION REMOVED
    -- IF NOT (p_phone ~ '^01[0-9]{9}$') THEN
    --    RAISE EXCEPTION 'Phone number must be in Egyptian format (01XXXXXXXXX)';
    -- END IF;

    -- Update the job offer (RLS will ensure user owns it)
    UPDATE public.job_offers
    SET 
        title = p_title,
        description = p_description,
        phone = p_phone,
        workplace_address = p_workplace_address
    WHERE id = p_job_id AND user_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Job offer not found or unauthorized';
    END IF;

    RETURN TRUE;
END;
$$;

-- 7. Grant permissions again (just in case)
GRANT EXECUTE ON FUNCTION public.get_all_job_offers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_all_job_offers() TO anon;
GRANT EXECUTE ON FUNCTION public.get_my_job_offers(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_job_offer(TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_job_offer(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
