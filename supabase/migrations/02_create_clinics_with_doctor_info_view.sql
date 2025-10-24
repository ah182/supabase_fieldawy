-- =========================================================
-- Create View: clinics_with_doctor_info
-- This view joins the clinics table with the users table
-- to provide a consolidated data source for the map, 
-- including clinic details and doctor information for searching.
-- =========================================================

CREATE OR REPLACE VIEW public.clinics_with_doctor_info AS
SELECT
  c.id as clinic_id,
  c.clinic_name,
  c.latitude,
  c.longitude,
  c.address,
  c.phone_number as clinic_phone_number,
  c.created_at,
  c.updated_at,
  u.id as user_id,
  u.display_name as doctor_name,
  u.whatsapp_number as doctor_whatsapp_number,
  u.photo_url as doctor_photo_url
FROM
  public.clinics c
JOIN
  public.users u ON c.user_id = u.id;

-- Grant usage to authenticated users
GRANT SELECT ON public.clinics_with_doctor_info TO authenticated;
