-- Query 1: Check the prize claim window
SELECT start_date, start_date + interval '30 days' as claim_window_end
FROM public.leaderboard_seasons
WHERE is_active = true;

-- Query 2: Check your rank in the previous season
SELECT *
FROM public.season_rankings
WHERE user_id = 'd2dc420f-bdf4-4dd9-8212-279cb74922a9'
ORDER BY season_id DESC;
