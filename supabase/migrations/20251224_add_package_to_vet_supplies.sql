-- ====================================
-- Add Package to Vet Supplies (FIXED)
-- Created: 2025-12-24
-- Description: Adds 'package' column and correctly drops/recreates functions to avoid type conflicts
-- ====================================

-- 1. حذف الدوال القديمة أولاً لتجنب خطأ "cannot change return type"
DROP FUNCTION IF EXISTS public.get_all_vet_supplies();
DROP FUNCTION IF EXISTS public.get_my_vet_supplies(uuid);
DROP FUNCTION IF EXISTS public.create_vet_supply(text, text, numeric, text, text);
DROP FUNCTION IF EXISTS public.update_vet_supply(uuid, text, text, numeric, text, text);

-- 2. إضافة العمود إذا لم يكن موجوداً
ALTER TABLE public.vet_supplies 
ADD COLUMN IF NOT EXISTS package TEXT DEFAULT 'Unit';

COMMENT ON COLUMN public.vet_supplies.package IS 'Package size/type description';

-- 3. إعادة إنشاء الدوال بالهيكل الجديد

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
    package TEXT,
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
        vs.package,
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
    package TEXT,
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
        vs.package,
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
    p_phone TEXT,
    p_package TEXT DEFAULT 'Unit'
)
RETURNS UUID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_supply_id UUID;
BEGIN
    INSERT INTO public.vet_supplies (user_id, name, description, price, image_url, phone, package)
    VALUES (auth.uid(), p_name, p_description, p_price, p_image_url, p_phone, p_package)
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
    p_phone TEXT,
    p_package TEXT DEFAULT 'Unit'
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.vet_supplies
    SET 
        name = p_name,
        description = p_description,
        price = p_price,
        image_url = p_image_url,
        phone = p_phone,
        package = p_package
    WHERE id = p_supply_id AND user_id = auth.uid();

    RETURN TRUE;
END;
$$;

-- 4. منح الصلاحيات
GRANT EXECUTE ON FUNCTION public.get_all_vet_supplies() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_my_vet_supplies(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_vet_supply(TEXT, TEXT, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_vet_supply(UUID, TEXT, TEXT, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;