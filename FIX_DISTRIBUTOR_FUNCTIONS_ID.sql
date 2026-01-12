-- Fix increment/decrement functions to use 'id' instead of 'uid'

-- 1. Increment Recommendation
CREATE OR REPLACE FUNCTION increment_distributor_recommendation(distributor_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET recommendation_count = COALESCE(recommendation_count, 0) + 1
  WHERE id = distributor_id; -- Changed uid to id
END;
$$;

-- 2. Increment Report
CREATE OR REPLACE FUNCTION increment_distributor_report(distributor_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET report_count = COALESCE(report_count, 0) + 1
  WHERE id = distributor_id; -- Changed uid to id
END;
$$;

-- 3. Decrement Recommendation
CREATE OR REPLACE FUNCTION decrement_distributor_recommendation(distributor_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET recommendation_count = GREATEST(COALESCE(recommendation_count, 0) - 1, 0)
  WHERE id = distributor_id; -- Changed uid to id
END;
$$;

-- 4. Decrement Report
CREATE OR REPLACE FUNCTION decrement_distributor_report(distributor_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET report_count = GREATEST(COALESCE(report_count, 0) - 1, 0)
  WHERE id = distributor_id; -- Changed uid to id
END;
$$;
