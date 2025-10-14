-- ====================================
-- Job Offers System
-- Created: 2025-01-24
-- Description: Complete job offers system with RLS policies
-- ====================================

-- Drop existing objects if they exist
DROP TABLE IF EXISTS public.job_offers CASCADE;
DROP FUNCTION IF EXISTS public.get_all_job_offers() CASCADE;
DROP FUNCTION IF EXISTS public.get_my_job_offers(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.create_job_offer(text, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.update_job_offer(uuid, text, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.delete_job_offer(uuid) CASCADE;

-- ====================================
-- 1. Create job_offers table
-- ====================================

CREATE TABLE public.job_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL CHECK (char_length(title) >= 10 AND char_length(title) <= 200),
    description TEXT NOT NULL CHECK (char_length(description) >= 50 AND char_length(description) <= 2000),
    phone TEXT NOT NULL CHECK (phone ~ '^\+?[1-9]\d{1,14}$'),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'closed', 'expired')),
    views_count INTEGER DEFAULT 0 CHECK (views_count >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comments for documentation
COMMENT ON TABLE public.job_offers IS 'Stores job offers posted by users';
COMMENT ON COLUMN public.job_offers.id IS 'Unique identifier for the job offer';
COMMENT ON COLUMN public.job_offers.user_id IS 'ID of the user who posted the job offer';
COMMENT ON COLUMN public.job_offers.title IS 'Job title (10-200 characters)';
COMMENT ON COLUMN public.job_offers.description IS 'Job description (50-2000 characters)';
COMMENT ON COLUMN public.job_offers.phone IS 'Contact phone number (International format: +[country code][number])';
COMMENT ON COLUMN public.job_offers.status IS 'Job offer status: active, closed, or expired';
COMMENT ON COLUMN public.job_offers.views_count IS 'Number of times this job offer has been viewed';

-- ====================================
-- 2. Create indexes for performance
-- ====================================

CREATE INDEX idx_job_offers_user_id ON public.job_offers(user_id);
CREATE INDEX idx_job_offers_status ON public.job_offers(status);
CREATE INDEX idx_job_offers_created_at ON public.job_offers(created_at DESC);
CREATE INDEX idx_job_offers_user_status ON public.job_offers(user_id, status);

-- ====================================
-- 3. Create trigger to update updated_at
-- ====================================

CREATE OR REPLACE FUNCTION public.update_job_offer_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_job_offer_timestamp
    BEFORE UPDATE ON public.job_offers
    FOR EACH ROW
    EXECUTE FUNCTION public.update_job_offer_timestamp();

-- ====================================
-- 4. Enable Row Level Security (RLS)
-- ====================================

ALTER TABLE public.job_offers ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view active job offers
CREATE POLICY "job_offers_select_active"
    ON public.job_offers
    FOR SELECT
    USING (status = 'active');

-- Policy: Users can view all their own job offers regardless of status
CREATE POLICY "job_offers_select_own"
    ON public.job_offers
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Authenticated users can insert job offers
CREATE POLICY "job_offers_insert_authenticated"
    ON public.job_offers
    FOR INSERT
    WITH CHECK (auth.uid() = user_id AND auth.uid() IS NOT NULL);

-- Policy: Users can update only their own job offers
CREATE POLICY "job_offers_update_own"
    ON public.job_offers
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete only their own job offers
CREATE POLICY "job_offers_delete_own"
    ON public.job_offers
    FOR DELETE
    USING (auth.uid() = user_id);

-- ====================================
-- 5. Create helper functions
-- ====================================

-- Function: Get all active job offers with user info
CREATE OR REPLACE FUNCTION public.get_all_job_offers()
RETURNS TABLE (
    id UUID,
    user_id UUID,
    user_name TEXT,
    title TEXT,
    description TEXT,
    phone TEXT,
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

-- Function: Get user's own job offers
CREATE OR REPLACE FUNCTION public.get_my_job_offers(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    title TEXT,
    description TEXT,
    phone TEXT,
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
        jo.status,
        jo.views_count,
        jo.created_at,
        jo.updated_at
    FROM public.job_offers jo
    WHERE jo.user_id = p_user_id
    ORDER BY jo.created_at DESC;
END;
$$;

-- Function: Create a new job offer
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

    IF NOT (p_phone ~ '^01[0-9]{9}$') THEN
        RAISE EXCEPTION 'Phone number must be in Egyptian format (01XXXXXXXXX)';
    END IF;

    -- Insert the job offer
    INSERT INTO public.job_offers (user_id, title, description, phone)
    VALUES (auth.uid(), p_title, p_description, p_phone)
    RETURNING id INTO v_job_id;

    RETURN v_job_id;
END;
$$;

-- Function: Update a job offer
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

    IF NOT (p_phone ~ '^01[0-9]{9}$') THEN
        RAISE EXCEPTION 'Phone number must be in Egyptian format (01XXXXXXXXX)';
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

-- Function: Delete a job offer
CREATE OR REPLACE FUNCTION public.delete_job_offer(p_job_id UUID)
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

    -- Delete the job offer (RLS will ensure user owns it)
    DELETE FROM public.job_offers
    WHERE id = p_job_id AND user_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Job offer not found or unauthorized';
    END IF;

    RETURN TRUE;
END;
$$;

-- Function: Increment views count
CREATE OR REPLACE FUNCTION public.increment_job_views(p_job_id UUID)
RETURNS VOID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.job_offers
    SET views_count = views_count + 1
    WHERE id = p_job_id AND status = 'active';
END;
$$;

-- Function: Close a job offer
CREATE OR REPLACE FUNCTION public.close_job_offer(p_job_id UUID)
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

    -- Close the job offer (RLS will ensure user owns it)
    UPDATE public.job_offers
    SET status = 'closed'
    WHERE id = p_job_id AND user_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Job offer not found or unauthorized';
    END IF;

    RETURN TRUE;
END;
$$;

-- ====================================
-- 6. Grant necessary permissions
-- ====================================

-- Grant access to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.job_offers TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_all_job_offers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_job_offers(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_job_offer(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_job_offer(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_job_offer(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_job_views(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_job_offer(UUID) TO authenticated;

-- Grant read-only access to anonymous users for viewing active jobs
GRANT SELECT ON public.job_offers TO anon;
GRANT EXECUTE ON FUNCTION public.get_all_job_offers() TO anon;

-- ====================================
-- 7. Create a view for active jobs (optional)
-- ====================================

CREATE OR REPLACE VIEW public.active_job_offers AS
SELECT 
    jo.id,
    jo.user_id,
    COALESCE(u.display_name, u.email, 'مستخدم') as user_name,
    jo.title,
    jo.description,
    jo.phone,
    jo.views_count,
    jo.created_at,
    jo.updated_at
FROM public.job_offers jo
LEFT JOIN public.users u ON jo.user_id = u.id
WHERE jo.status = 'active'
ORDER BY jo.created_at DESC;

GRANT SELECT ON public.active_job_offers TO authenticated, anon;

-- ====================================
-- 8. Insert sample data for testing (optional - remove in production)
-- ====================================

-- Uncomment the following lines to insert sample data:
/*
INSERT INTO public.job_offers (user_id, title, description, phone) VALUES
(auth.uid(), 'طبيب بيطري مطلوب للعمل في عيادة', 'مطلوب طبيب بيطري خبرة لا تقل عن 3 سنوات للعمل في عيادة بيطرية كبرى في القاهرة. المزايا: راتب تنافسي، تأمينات اجتماعية، بيئة عمل احترافية.', '01012345678'),
(auth.uid(), 'مساعد طبيب بيطري', 'مطلوب مساعد طبيب بيطري للعمل في عيادة بيطرية بالجيزة. يفضل وجود خبرة سابقة. ساعات عمل مرنة وراتب مجزي.', '01123456789');
*/

-- ====================================
-- End of Job Offers System Migration
-- ====================================
