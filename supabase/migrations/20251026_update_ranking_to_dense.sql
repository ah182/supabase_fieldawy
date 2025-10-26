-- This migration updates the user ranking function to use DENSE_RANK.
-- DENSE_RANK ensures that ranks are sequential without any gaps in case of ties.

CREATE OR REPLACE FUNCTION public.update_user_ranks()
RETURNS void AS $$
BEGIN
  WITH ranked_users AS (
    SELECT
      id,
      -- Changed RANK() to DENSE_RANK() to prevent gaps in ranking
      DENSE_RANK() OVER (ORDER BY points DESC) as new_rank
    FROM
      public.users
  )
  UPDATE public.users
  SET
    rank = ranked_users.new_rank
  FROM
    ranked_users
  WHERE
    public.users.id = ranked_users.id;
END;
$$ LANGUAGE plpgsql;
