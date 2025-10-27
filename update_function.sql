-- This script creates and schedules a function to manage 30-day leaderboard seasons.

-- Step 1: Create the function to start a new season.
CREATE OR REPLACE FUNCTION public.start_new_leaderboard_season()
RETURNS text AS $$
DECLARE
  active_season RECORD;
  new_season_id BIGINT;
BEGIN
  -- Check for a currently active season
  SELECT id, end_date INTO active_season FROM public.leaderboard_seasons WHERE is_active = true LIMIT 1;

  -- If no active season exists, create the first one.
  IF active_season IS NULL THEN
    RAISE NOTICE 'No active season found. Creating the first season.';
    INSERT INTO public.leaderboard_seasons (start_date, end_date, is_active)
    VALUES (now(), now() + interval '30 days', true)
    RETURNING id INTO new_season_id;
    RETURN 'First season created with ID: ' || new_season_id;
  END IF;

  -- If an active season exists, check if it has ended.
  IF active_season.end_date <= now() THEN
    RAISE NOTICE 'Season % has ended. Archiving and starting a new season.', active_season.id;

    -- 1. Archive rankings for users with points > 0
    INSERT INTO public.season_rankings (season_id, user_id, final_rank, final_points)
    SELECT active_season.id, id, rank, points
    FROM public.users
    WHERE points > 0;

    -- 2. Deactivate the old season
    UPDATE public.leaderboard_seasons
    SET is_active = false
    WHERE id = active_season.id;

    -- 3. Reset all user points and ranks
    UPDATE public.users
    SET points = 0, rank = null
    WHERE points > 0;

    -- 4. Create the new season
    INSERT INTO public.leaderboard_seasons (start_date, end_date, is_active)
    VALUES (now(), now() + interval '30 days', true)
    RETURNING id INTO new_season_id;

    RETURN format('Archived season %s and started new season with ID: %s', active_season.id, new_season_id);
  ELSE
    -- If the season has not ended, do nothing.
    RAISE NOTICE 'Season % is still active.', active_season.id;
    RETURN 'Season ' || active_season.id || ' is still active. No action taken.';
  END IF;

END;
$$ LANGUAGE plpgsql;


-- Step 2: Schedule the function to run once every day at midnight UTC.
-- It will check daily if a new season needs to be started.
SELECT cron.schedule(
  'start-new-leaderboard-season-job',
  '0 0 * * *', -- Every day at midnight UTC
  'SELECT public.start_new_leaderboard_season()'
);
