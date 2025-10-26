CREATE OR REPLACE FUNCTION public.increment_user_points(user_id_param UUID, points_to_add INT)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET points = points + points_to_add
  WHERE id = user_id_param;
END;
$$ LANGUAGE plpgsql;
