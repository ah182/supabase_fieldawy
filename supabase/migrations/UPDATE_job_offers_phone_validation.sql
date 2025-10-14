-- ====================================
-- Update Job Offers Phone Validation
-- Created: 2025-01-24
-- Description: Update phone validation to support international format
-- ====================================

-- Step 1: First, update existing Egyptian phone numbers to international format
-- Convert numbers starting with 01 to +20 format
UPDATE public.job_offers 
SET phone = CONCAT('+20', phone) 
WHERE phone ~ '^01[0-9]{9}$';

-- Convert numbers starting with 1 (without 0) to +20 format
UPDATE public.job_offers 
SET phone = CONCAT('+20', phone) 
WHERE phone ~ '^1[0-9]{9}$' AND NOT phone LIKE '+%';

-- Ensure all numbers have + prefix if they don't
UPDATE public.job_offers 
SET phone = CONCAT('+', phone) 
WHERE phone ~ '^[1-9]\d{1,14}$' AND NOT phone LIKE '+%';

-- Step 2: Drop the old constraint
ALTER TABLE public.job_offers 
DROP CONSTRAINT IF EXISTS job_offers_phone_check;

-- Step 3: Add the new constraint for international phone numbers
ALTER TABLE public.job_offers 
ADD CONSTRAINT job_offers_phone_check 
CHECK (phone ~ '^\+?[1-9]\d{1,14}$');

-- Update comment
COMMENT ON COLUMN public.job_offers.phone IS 'Contact phone number (International format: +[country code][number])';

-- Update create_job_offer function
CREATE OR REPLACE FUNCTION public.create_job_offer(
    p_title TEXT,
    p_description TEXT,
    p_phone TEXT
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

    IF NOT (p_phone ~ '^\+?[1-9]\d{1,14}$') THEN
        RAISE EXCEPTION 'Phone number must be in valid international format';
    END IF;

    -- Insert the job offer
    INSERT INTO public.job_offers (user_id, title, description, phone)
    VALUES (auth.uid(), p_title, p_description, p_phone)
    RETURNING id INTO v_job_id;

    RETURN v_job_id;
END;
$$;

-- Update update_job_offer function
CREATE OR REPLACE FUNCTION public.update_job_offer(
    p_job_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_phone TEXT
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

    IF NOT (p_phone ~ '^\+?[1-9]\d{1,14}$') THEN
        RAISE EXCEPTION 'Phone number must be in valid international format';
    END IF;

    -- Update the job offer (RLS will ensure user owns it)
    UPDATE public.job_offers
    SET 
        title = p_title,
        description = p_description,
        phone = p_phone
    WHERE id = p_job_id AND user_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Job offer not found or unauthorized';
    END IF;

    RETURN TRUE;
END;
$$;
