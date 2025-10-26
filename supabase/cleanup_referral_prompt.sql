-- This script reverses the changes from the '20251026_add_seen_prompt_flag.sql' migration.
-- It cleans up the database by removing the now-unused column and function related to the 'has_seen_referral_prompt' feature.

-- Drop the function if it exists
DROP FUNCTION IF EXISTS public.mark_referral_prompt_seen();

-- Drop the column from the users table if it exists
ALTER TABLE public.users
DROP COLUMN IF EXISTS has_seen_referral_prompt;
