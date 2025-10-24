-- This function creates or updates a clinic and ensures the geography 'location' field is correctly populated.
CREATE OR REPLACE FUNCTION public.upsert_clinic(
  p_user_id uuid,
  p_clinic_name text,
  p_latitude double precision,
  p_longitude double precision,
  p_address text,
  p_phone_number text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.clinics (user_id, clinic_name, latitude, longitude, address, phone_number, location)
  VALUES (p_user_id, p_clinic_name, p_latitude, p_longitude, p_address, p_phone_number, ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography)
  ON CONFLICT (user_id)
  DO UPDATE SET
    clinic_name = p_clinic_name,
    latitude = p_latitude,
    longitude = p_longitude,
    address = p_address,
    phone_number = p_phone_number,
    location = ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
    updated_at = NOW();
END;
$$;

-- Grant execute permissions for the function
GRANT EXECUTE ON FUNCTION public.upsert_clinic(uuid, text, double precision, double precision, text, text) TO anon, authenticated;
