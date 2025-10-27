-- Function to reset a user's referral code.
CREATE OR REPLACE FUNCTION public.reset_referral_code(user_id_param UUID)
RETURNS TEXT AS $$
DECLARE
  new_code TEXT;
  is_unique BOOLEAN := false;
  chars text[] := ARRAY['a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','0','1','2','3','4','5','6','7','8','9'];
  random_str text := '';
  i integer := 0;
BEGIN
  -- Generate a new unique code
  WHILE NOT is_unique LOOP
    random_str := '';
    for i in 1..6 loop
      random_str := random_str || chars[1+floor(random()*(array_length(chars, 1)))::int];
    end loop;
    new_code := 'FS_' || random_str;
    is_unique := NOT EXISTS (SELECT 1 FROM public.users WHERE referral_code = new_code);
  END LOOP;

  -- Update the user's record with the newly generated code
  UPDATE public.users SET referral_code = new_code WHERE id = user_id_param;

  -- Return the new code
  RETURN new_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.reset_referral_code(UUID) TO authenticated;
