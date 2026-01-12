-- Function to decrement recommendation count (prevents negative values)
CREATE OR REPLACE FUNCTION decrement_distributor_recommendation(distributor_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET recommendation_count = GREATEST(COALESCE(recommendation_count, 0) - 1, 0)
  WHERE uid = distributor_id;
END;
$$;

-- Function to decrement report count (prevents negative values)
CREATE OR REPLACE FUNCTION decrement_distributor_report(distributor_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET report_count = GREATEST(COALESCE(report_count, 0) - 1, 0)
  WHERE uid = distributor_id;
END;
$$;