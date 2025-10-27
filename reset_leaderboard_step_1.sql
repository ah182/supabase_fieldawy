-- Step 1: Update the end date of the current active season to a past date.
-- Replace [YOUR-PASSWORD] with your actual database password.
-- Run this command in your terminal.
psql "postgres://postgres:[YOUR-PASSWORD]@db.rkukzuwerbvmueuxadul.supabase.co:5432/postgres" -c "UPDATE public.leaderboard_seasons SET end_date = now() - interval '1 day' WHERE is_active = true"