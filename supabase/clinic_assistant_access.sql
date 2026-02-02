-- Add clinic_access_code to users table (public.users)
-- Format: FC-XXXXX (Random 5 chars)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS clinic_access_code TEXT;

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS idx_users_clinic_access_code ON public.users(clinic_access_code);

-- Function to find specific user by access code (security definer to bypass RLS for this specific check)
-- This allows the login screen to find the doctor's User ID using only the code.
CREATE OR REPLACE FUNCTION get_user_id_by_clinic_code(code_input TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    found_user_id UUID;
BEGIN
    SELECT id INTO found_user_id 
    FROM public.users
    WHERE clinic_access_code = code_input
    LIMIT 1;
    
    RETURN found_user_id;
END;
$$;
