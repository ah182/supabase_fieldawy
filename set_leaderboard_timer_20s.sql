-- Set the leaderboard timer to 20 seconds remaining.
-- Replace [YOUR-PASSWORD] with your actual database password.
-- Run this command in your terminal.
psql "postgres://postgres:[YOUR-PASSWORD]@db.rkukzuwerbvmueuxadul.supabase.co:5432/postgres" -c "UPDATE public.leaderboard_seasons SET end_date = now() + interval '20 seconds' WHERE is_active = true"