-- ====================================
-- Vet Supplies System
-- Created: 2025-12-14
-- Description: Complete vet supplies system with RLS policies
-- ====================================

-- Drop existing objects if they exist
DROP TABLE IF EXISTS public.vet_supplies CASCADE;
DROP FUNCTION IF EXISTS public.get_all_vet_supplies() CASCADE;
DROP FUNCTION IF EXISTS public.get_my_vet_supplies(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.create_vet_supply(text, text, numeric, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.update_vet_supply(uuid, text, text, numeric, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.delete_vet_supply(uuid) CASCADE;

-- ====================================
-- 1. Create vet_supplies table
-- ====================================

CREATE TABLE public.vet_supplies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (char_length(name) >= 3 AND char_length(name) <= 200),
    description TEXT NOT NULL CHECK (char_length(description) >= 10 AND char_length(description) <= 2000),
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    image_url TEXT NOT NULL,
    phone TEXT NOT NULL CHECK (phone ~ '^\+?[1-9]\d{1,14}$'),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'sold', 'inactive')),
    views_count INTEGER DEFAULT 0 CHECK (views_count >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comments for documentation
COMMENT ON TABLE public.vet_supplies IS 'Stores veterinary supplies posted by users';
COMMENT ON COLUMN public.vet_supplies.id IS 'Unique identifier for the supply';
COMMENT ON COLUMN public.vet_supplies.user_id IS 'ID of the user who posted the supply';
COMMENT ON COLUMN public.vet_supplies.name IS 'Supply name (3-200 characters)';
COMMENT ON COLUMN public.vet_supplies.description IS 'Supply description (10-2000 characters)';
COMMENT ON COLUMN public.vet_supplies.price IS 'Price in EGP';
COMMENT ON COLUMN public.vet_supplies.image_url IS 'Cloudinary URL for supply image';
COMMENT ON COLUMN public.vet_supplies.phone IS 'Contact phone number (International format: +[country code][number])';
COMMENT ON COLUMN public.vet_supplies.status IS 'Supply status: active, sold, or inactive';
COMMENT ON COLUMN public.vet_supplies.views_count IS 'Number of times this supply has been viewed';

-- ====================================
-- 2. Create indexes for performance
-- ====================================

CREATE INDEX idx_vet_supplies_user_id ON public.vet_supplies(user_id);
CREATE INDEX idx_vet_supplies_status ON public.vet_supplies(status);
CREATE INDEX idx_vet_supplies_created_at ON public.vet_supplies(created_at DESC);
CREATE INDEX idx_vet_supplies_user_status ON public.vet_supplies(user_id, status);
CREATE INDEX idx_vet_supplies_price ON public.vet_supplies(price);

-- ====================================
-- 3. Create trigger to update updated_at
-- ====================================

CREATE OR REPLACE FUNCTION public.update_vet_supply_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_vet_supply_timestamp
    BEFORE UPDATE ON public.vet_supplies
    FOR EACH ROW
    EXECUTE FUNCTION public.update_vet_supply_timestamp();

-- ====================================
-- 4. Enable Row Level Security (RLS)
-- ====================================

ALTER TABLE public.vet_supplies ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view active vet supplies
CREATE POLICY "vet_supplies_select_active"
    ON public.vet_supplies
    FOR SELECT
    USING (status = 'active');

-- Policy: Users can view all their own vet supplies regardless of status
CREATE POLICY "vet_supplies_select_own"
    ON public.vet_supplies
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Authenticated users can insert vet supplies
CREATE POLICY "vet_supplies_insert_authenticated"
    ON public.vet_supplies
    FOR INSERT
    WITH CHECK (auth.uid() = user_id AND auth.uid() IS NOT NULL);

-- Policy: Users can update only their own vet supplies
CREATE POLICY "vet_supplies_update_own"
    ON public.vet_supplies
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete only their own vet supplies
CREATE POLICY "vet_supplies_delete_own"
    ON public.vet_supplies
    FOR DELETE
    USING (auth.uid() = user_id);

-- ====================================
-- 5. Create helper functions
-- ====================================

-- Function: Get all active vet supplies with user info
CREATE OR REPLACE FUNCTION public.get_all_vet_supplies()
RETURNS TABLE (
    id UUID,
    user_id UUID,
    user_name TEXT,
    name TEXT,
    description TEXT,
    price NUMERIC,
    image_url TEXT,
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
        vs.id,
        vs.user_id,
        COALESCE(u.display_name, u.email, 'مستخدم') as user_name,
        vs.name,
        vs.description,
        vs.price,
        vs.image_url,
        vs.phone,
        vs.status,
        vs.views_count,
        vs.created_at,
        vs.updated_at
    FROM public.vet_supplies vs
    LEFT JOIN public.users u ON vs.user_id = u.id
    WHERE vs.status = 'active'
    ORDER BY vs.created_at DESC;
END;
$$;

-- Function: Get user's own vet supplies
CREATE OR REPLACE FUNCTION public.get_my_vet_supplies(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    user_name TEXT,
    name TEXT,
    description TEXT,
    price NUMERIC,
    image_url TEXT,
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
        vs.id,
        vs.user_id,
        COALESCE(u.display_name, u.email, 'مستخدم') as user_name,
        vs.name,
        vs.description,
        vs.price,
        vs.image_url,
        vs.phone,
        vs.status,
        vs.views_count,
        vs.created_at,
        vs.updated_at
    FROM public.vet_supplies vs
    LEFT JOIN public.users u ON vs.user_id = u.id
    WHERE vs.user_id = p_user_id
    ORDER BY vs.created_at DESC;
END;
$$;

-- Function: Create a new vet supply
CREATE OR REPLACE FUNCTION public.create_vet_supply(
    p_name TEXT,
    p_description TEXT,
    p_price NUMERIC,
    p_image_url TEXT,
    p_phone TEXT
)
RETURNS UUID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_supply_id UUID;
BEGIN
    -- Check if user is authenticated
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    -- Validate inputs
    IF char_length(p_name) < 3 OR char_length(p_name) > 200 THEN
        RAISE EXCEPTION 'Name must be between 3 and 200 characters';
    END IF;

    IF char_length(p_description) < 10 OR char_length(p_description) > 2000 THEN
        RAISE EXCEPTION 'Description must be between 10 and 2000 characters';
    END IF;

    IF p_price < 0 THEN
        RAISE EXCEPTION 'Price must be greater than or equal to 0';
    END IF;

    IF char_length(p_image_url) < 10 THEN
        RAISE EXCEPTION 'Invalid image URL';
    END IF;

    IF NOT (p_phone ~ '^\+?[1-9]\d{1,14}$') THEN
        RAISE EXCEPTION 'Invalid phone number format';
    END IF;

    -- Insert the vet supply
    INSERT INTO public.vet_supplies (user_id, name, description, price, image_url, phone)
    VALUES (auth.uid(), p_name, p_description, p_price, p_image_url, p_phone)
    RETURNING id INTO v_supply_id;

    RETURN v_supply_id;
END;
$$;

-- Function: Update a vet supply
CREATE OR REPLACE FUNCTION public.update_vet_supply(
    p_supply_id UUID,
    p_name TEXT,
    p_description TEXT,
    p_price NUMERIC,
    p_image_url TEXT,
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
    IF char_length(p_name) < 3 OR char_length(p_name) > 200 THEN
        RAISE EXCEPTION 'Name must be between 3 and 200 characters';
    END IF;

    IF char_length(p_description) < 10 OR char_length(p_description) > 2000 THEN
        RAISE EXCEPTION 'Description must be between 10 and 2000 characters';
    END IF;

    IF p_price < 0 THEN
        RAISE EXCEPTION 'Price must be greater than or equal to 0';
    END IF;

    IF char_length(p_image_url) < 10 THEN
        RAISE EXCEPTION 'Invalid image URL';
    END IF;

    IF NOT (p_phone ~ '^\+?[1-9]\d{1,14}$') THEN
        RAISE EXCEPTION 'Invalid phone number format';
    END IF;

    -- Update the vet supply (RLS will ensure user owns it)
    UPDATE public.vet_supplies
    SET 
        name = p_name,
        description = p_description,
        price = p_price,
        image_url = p_image_url,
        phone = p_phone
    WHERE id = p_supply_id AND user_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Supply not found or unauthorized';
    END IF;

    RETURN TRUE;
END;
$$;

-- Function: Delete a vet supply
CREATE OR REPLACE FUNCTION public.delete_vet_supply(p_supply_id UUID)
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

    -- Delete the vet supply (RLS will ensure user owns it)
    DELETE FROM public.vet_supplies
    WHERE id = p_supply_id AND user_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Supply not found or unauthorized';
    END IF;

    RETURN TRUE;
END;
$$;

-- Function: Increment views count
CREATE OR REPLACE FUNCTION public.increment_vet_supply_views(p_supply_id UUID)
RETURNS VOID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.vet_supplies
    SET views_count = views_count + 1
    WHERE id = p_supply_id AND status = 'active';
END;
$$;

-- ====================================
-- 6. Grant necessary permissions
-- ====================================

-- Grant access to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vet_supplies TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_all_vet_supplies() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_vet_supplies(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_vet_supply(TEXT, TEXT, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_vet_supply(UUID, TEXT, TEXT, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_vet_supply(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_vet_supply_views(UUID) TO authenticated;

-- Grant read-only access to anonymous users for viewing active supplies
GRANT SELECT ON public.vet_supplies TO anon;
GRANT EXECUTE ON FUNCTION public.get_all_vet_supplies() TO anon;

-- ====================================
-- 7. Create a view for active supplies (optional)
-- ====================================

CREATE OR REPLACE VIEW public.active_vet_supplies AS
SELECT 
    vs.id,
    vs.user_id,
    COALESCE(u.display_name, u.email, 'مستخدم') as user_name,
    vs.name,
    vs.description,
    vs.price,
    vs.image_url,
    vs.phone,
    vs.views_count,
    vs.created_at,
    vs.updated_at
FROM public.vet_supplies vs
LEFT JOIN public.users u ON vs.user_id = u.id
WHERE vs.status = 'active'
ORDER BY vs.created_at DESC;

GRANT SELECT ON public.active_vet_supplies TO authenticated, anon;

-- ====================================
-- End of Vet Supplies System Migration
-- ====================================
