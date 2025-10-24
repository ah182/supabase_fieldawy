-- ================================================
-- Add Location Fields to Users Table
-- ================================================

-- Add location columns to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS last_latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS last_longitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMP WITH TIME ZONE;

-- Add index for location queries
CREATE INDEX IF NOT EXISTS idx_users_location ON public.users(last_latitude, last_longitude);
CREATE INDEX IF NOT EXISTS idx_users_last_update ON public.users(last_location_update);

-- Add comment
COMMENT ON COLUMN public.users.last_latitude IS 'Last known latitude of user';
COMMENT ON COLUMN public.users.last_longitude IS 'Last known longitude of user';
COMMENT ON COLUMN public.users.last_location_update IS 'Timestamp of last location update';

-- ================================================
-- Function to Update User Location
-- ================================================

CREATE OR REPLACE FUNCTION update_user_location(
    p_user_id UUID,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user can update (prevent too frequent updates)
    IF EXISTS (
        SELECT 1 FROM public.users
        WHERE id = p_user_id 
        AND last_location_update > NOW() - INTERVAL '30 seconds'
    ) THEN
        RAISE EXCEPTION 'Please wait 30 seconds before updating location again';
    END IF;

    -- Update user location
    UPDATE public.users
    SET 
        last_latitude = p_latitude,
        last_longitude = p_longitude,
        last_location_update = NOW()
    WHERE id = p_user_id;

    RETURN TRUE;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_user_location TO authenticated;

-- ================================================
-- Function to Get Nearby Clinics
-- ================================================

CREATE OR REPLACE FUNCTION get_nearby_clinics(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_radius_km DOUBLE PRECISION DEFAULT 50.0
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    clinic_name TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address TEXT,
    phone_number TEXT,
    distance_km DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.user_id,
        c.clinic_name,
        c.latitude,
        c.longitude,
        c.address,
        c.phone_number,
        -- Calculate distance using Haversine formula
        (
            6371 * acos(
                cos(radians(p_latitude)) * 
                cos(radians(c.latitude)) * 
                cos(radians(c.longitude) - radians(p_longitude)) + 
                sin(radians(p_latitude)) * 
                sin(radians(c.latitude))
            )
        ) AS distance_km,
        c.created_at
    FROM public.clinics c
    WHERE 
        -- Filter by approximate distance first (faster)
        c.latitude BETWEEN p_latitude - (p_radius_km / 111.0) 
                       AND p_latitude + (p_radius_km / 111.0)
        AND c.longitude BETWEEN p_longitude - (p_radius_km / 111.0) 
                            AND p_longitude + (p_radius_km / 111.0)
    HAVING 
        -- Then calculate exact distance
        (
            6371 * acos(
                cos(radians(p_latitude)) * 
                cos(radians(c.latitude)) * 
                cos(radians(c.longitude) - radians(p_longitude)) + 
                sin(radians(p_latitude)) * 
                sin(radians(c.latitude))
            )
        ) <= p_radius_km
    ORDER BY distance_km ASC;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_nearby_clinics TO authenticated;

-- ================================================
-- Comments
-- ================================================

COMMENT ON FUNCTION update_user_location IS 'Updates user current location with rate limiting';
COMMENT ON FUNCTION get_nearby_clinics IS 'Returns clinics within specified radius sorted by distance';
