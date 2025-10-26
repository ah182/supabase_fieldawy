-- 1. Add has_seen_referral_prompt column to users table
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS has_seen_referral_prompt BOOLEAN DEFAULT FALSE NOT NULL;

-- 2. Create function to mark the prompt as seen
CREATE OR REPLACE FUNCTION public.mark_referral_prompt_seen()
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET has_seen_referral_prompt = TRUE
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Grant execute permission
GRANT EXECUTE ON FUNCTION public.mark_referral_prompt_seen() TO authenticated;
