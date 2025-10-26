-- Function to generate a referral code for a user if it doesn't exist, and return it.
CREATE OR REPLACE FUNCTION public.generate_and_get_code(user_id_param UUID)
RETURNS TEXT AS $$
DECLARE
  existing_code TEXT;
  new_code TEXT;
  is_unique BOOLEAN := false;
  chars text[] := ARRAY['a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','0','1','2','3','4','5','6','7','8','9'];
  random_str text := '';
  i integer := 0;
BEGIN
  -- Check if a code already exists for the user
  SELECT referral_code INTO existing_code FROM public.users WHERE id = user_id_param;

  -- If the user already has a code, return it immediately
  IF existing_code IS NOT NULL THEN
    RETURN existing_code;
  END IF;

  -- If no code exists, generate a new unique one
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
GRANT EXECUTE ON FUNCTION public.generate_and_get_code(UUID) TO authenticated;
