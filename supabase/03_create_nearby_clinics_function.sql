-- First, drop the old function if it exists, to avoid conflicts
DROP FUNCTION IF EXISTS public.get_nearby_clinics(double precision, double precision, double precision);

-- Now, create the new, correct version of the function
CREATE OR REPLACE FUNCTION public.get_nearby_clinics(
  p_lat double precision,
  p_long double precision,
  p_radius_meters double precision
)
RETURNS SETOF clinics -- The function will return a set of records from the clinics table
LANGUAGE sql
STABLE
AS $$
  SELECT *
  FROM public.clinics
  WHERE ST_DWithin(
    location,
    ST_SetSRID(ST_MakePoint(p_long, p_lat), 4326)::geography,
    p_radius_meters
  );
$$;

-- Grant execute permissions for the function
GRANT EXECUTE ON FUNCTION public.get_nearby_clinics(double precision, double precision, double precision) TO anon, authenticated;