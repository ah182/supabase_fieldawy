-- Step 2: Start a new leaderboard season.
-- Replace [YOUR-PASSWORD] with your actual database password.
-- Run this command in your terminal.
psql "postgres://postgres:[YOUR-PASSWORD]@db.rkukzuwerbvmueuxadul.supabase.co:5432/postgres" -c "SELECT public.start_new_leaderboard_season()"