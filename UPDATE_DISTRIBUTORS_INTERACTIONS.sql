-- Add columns to users table for distributor interactions
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS recommendation_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS report_count integer DEFAULT 0;

-- Function to increment recommendation count
CREATE OR REPLACE FUNCTION increment_distributor_recommendation(distributor_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET recommendation_count = COALESCE(recommendation_count, 0) + 1
  WHERE uid = distributor_id;
END;
$$;

-- Function to increment report count
CREATE OR REPLACE FUNCTION increment_distributor_report(distributor_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET report_count = COALESCE(report_count, 0) + 1
  WHERE uid = distributor_id;
END;
$$;
