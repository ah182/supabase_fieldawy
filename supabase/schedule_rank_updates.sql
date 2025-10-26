-- This script creates a PostgreSQL function to update user ranks and schedules it to run daily.

-- Step 1: Create the function that calculates and updates user ranks.
-- This function uses a window function to efficiently calculate ranks based on points.
CREATE OR REPLACE FUNCTION public.update_user_ranks()
RETURNS void AS $$
BEGIN
  -- Use a Common Table Expression (CTE) for clarity
  WITH ranked_users AS (
    SELECT
      id,
      -- The RANK() window function assigns a rank based on the ordering of points.
      -- Users with the same number of points will receive the same rank.
      RANK() OVER (ORDER BY points DESC) as new_rank
    FROM
      public.users
  )
  -- Update the 'rank' column in the main 'users' table
  UPDATE public.users
  SET
    rank = ranked_users.new_rank
  FROM
    ranked_users
  WHERE
    -- Join the tables on the user ID
    public.users.id = ranked_users.id;
END;
$$ LANGUAGE plpgsql;


-- Step 2: Schedule the function to run once every day at midnight UTC.
-- This job will be named 'daily-rank-update'.
-- You can check the status of your cron jobs by querying the 'cron.job' table.
-- Make sure the pg_cron extension is enabled in your Supabase project.
SELECT cron.schedule(
  'daily-rank-update',
  '0 0 * * *', -- Runs every day at midnight UTC
  'SELECT public.update_user_ranks()'
);
