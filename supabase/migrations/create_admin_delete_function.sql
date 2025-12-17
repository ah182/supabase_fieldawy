-- Function to allow admins to delete a user from auth.users (and public.users via cascade)
-- Requires SECURITY DEFINER to bypass RLS and access auth schema

CREATE OR REPLACE FUNCTION public.delete_user_completely(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth 
AS $$
DECLARE
  caller_role text;
BEGIN
  -- Get the role of the caller
  SELECT role INTO caller_role
  FROM public.users
  WHERE id = auth.uid();

  -- Check permissions (only 'admin' can delete)
  IF caller_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Access denied. Only admins can delete users.';
  END IF;

  -- Delete from auth.users
  -- This should automatically cascade to public.users if Foreign Key is set with ON DELETE CASCADE.
  -- If not, we should delete from public.users manually first to be safe (or if FK restricts).
  
  -- Attempt to delete from public.users first (if constraint allows, otherwise rely on auth cascade)
  -- Actually, deleting from auth.users is the "root" delete.
  -- If FK has ON DELETE CASCADE, deleting auth.users deletes public.users.
  -- If FK has RESTRICT, we must delete public.users first.
  -- Let's try deleting public first, just in case.
  DELETE FROM public.users WHERE id = user_id;
  
  -- Delete from auth.users
  DELETE FROM auth.users WHERE id = user_id;
  
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_user_completely(uuid) TO authenticated;
