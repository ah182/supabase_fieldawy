-- =========================================================
-- Cleanup Script: Remove MapTiler API Usage Counter
-- This script removes the table and functions related to the
-- smart map switching system, as it is no longer in use.
-- =========================================================

-- Drop the function to reset the counter
DROP FUNCTION IF EXISTS public.reset_map_usage();

-- Drop the function to log a map request
DROP FUNCTION IF EXISTS public.log_map_request();

-- Drop the table that stores the API usage count
DROP TABLE IF EXISTS public.api_usage;

-- =========================================================
-- End of script
-- =========================================================
