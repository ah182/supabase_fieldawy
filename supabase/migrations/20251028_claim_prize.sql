-- Step 1: Create the claim_prize function
CREATE OR REPLACE FUNCTION public.claim_prize(
  p_user_id UUID,
  p_prize_won TEXT
)
RETURNS TEXT AS $$
DECLARE
  previous_season RECORD;
  winner_rank INT;
  already_claimed BOOLEAN;
  new_season_start_date TIMESTAMPTZ;
BEGIN
  -- 1. Find the most recently ended season
  SELECT * INTO previous_season
  FROM public.leaderboard_seasons
  WHERE is_active = false
  ORDER BY end_date DESC
  LIMIT 1;

  IF previous_season IS NULL THEN
    RETURN 'No previous season found to claim a prize from.';
  END IF;

  -- 2. Find the start date of the current active season
  SELECT start_date INTO new_season_start_date
  FROM public.leaderboard_seasons
  WHERE is_active = true
  ORDER BY start_date DESC
  LIMIT 1;

  -- 3. Check if the claim is within the 30-day window of the new season
  IF now() > new_season_start_date + interval '30 days' THEN
    RETURN 'The prize claim window for the previous season has expired.';
  END IF;

  -- 4. Check if the user was a top 5 winner in the previous season
  SELECT final_rank INTO winner_rank
  FROM public.season_rankings
  WHERE user_id = p_user_id AND season_id = previous_season.id;

  IF winner_rank IS NULL OR winner_rank > 5 THEN
    RETURN 'You were not a top 5 winner in the previous season.';
  END IF;

  -- 5. Check if the user has already claimed a prize for the previous season
  SELECT EXISTS (
    SELECT 1
    FROM public.claimed_prizes
    WHERE user_id = p_user_id AND season_id = previous_season.id
  ) INTO already_claimed;

  IF already_claimed THEN
    RETURN 'You have already claimed your prize for the previous season.';
  END IF;

  -- 6. Insert the claimed prize
  INSERT INTO public.claimed_prizes (user_id, season_id, prize_won)
  VALUES (p_user_id, previous_season.id, p_prize_won);

  RETURN 'Prize claimed successfully!';
END;
$$ LANGUAGE plpgsql;

-- Step 2: Modify RLS policies to use the claim_prize function

-- First, remove the existing insert policy
DROP POLICY IF EXISTS "Allow users to claim a prize" ON public.claimed_prizes;

-- Create a new policy that allows inserts only through the claim_prize function
-- This is a bit tricky as RLS policies on their own cannot directly call a function
-- before an insert. The standard way to enforce this is to revoke direct insert
-- permissions from the user role and only allow execution of the `claim_prize` function.

-- Revoke direct insert permission from the 'authenticated' role
REVOKE INSERT ON public.claimed_prizes FROM authenticated;

-- Grant execute permission on the function to the 'authenticated' role
GRANT EXECUTE ON FUNCTION public.claim_prize(UUID, TEXT) TO authenticated;
