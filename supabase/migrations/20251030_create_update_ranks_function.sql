CREATE OR REPLACE FUNCTION public.update_leaderboard_ranks()
RETURNS void AS $$
BEGIN
  WITH ranked_users AS (
    SELECT
      id,
      RANK() OVER (ORDER BY points DESC) as new_rank
    FROM public.users
  )
  UPDATE public.users
  SET rank = ranked_users.new_rank
  FROM ranked_users
  WHERE public.users.id = ranked_users.id;
END;
$$ LANGUAGE plpgsql;