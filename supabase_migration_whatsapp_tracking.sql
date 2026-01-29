-- Run this in your Supabase SQL Editor

-- 1. Add the column to users table
ALTER TABLE users ADD COLUMN whatsapp_clicks INTEGER DEFAULT 0;

-- 2. Create the increment function
CREATE OR REPLACE FUNCTION increment_distributor_whatsapp_clicks(distributor_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE users
  SET whatsapp_clicks = COALESCE(whatsapp_clicks, 0) + 1
  WHERE id = distributor_id;
END;
$$;
