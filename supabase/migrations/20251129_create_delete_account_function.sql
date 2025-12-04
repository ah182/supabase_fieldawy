-- Function to allow users to delete their own account
-- This function deletes the user from public.users. 
-- Ideally, a Supabase Edge Function should also be triggered to delete the user from auth.users using the Service Role Key.

CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_id UUID;
BEGIN
  current_user_id := auth.uid();
  
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete from public.users
  -- Assuming ON DELETE CASCADE is set up for related tables (products, reviews, etc.)
  DELETE FROM public.users WHERE id = current_user_id;
  
  -- Note: This does NOT delete from auth.users automatically unless you have a trigger or Edge Function.
  -- For Google Play compliance, "initiating" the deletion and removing public data is often the first step.
  -- You should ideally set up a trigger on public.users delete to call an Edge Function to remove auth.users.
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;
