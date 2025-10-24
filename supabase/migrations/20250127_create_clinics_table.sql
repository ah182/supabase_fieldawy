-- ================================================
-- Create Clinics Table for Doctor Location Tracking
-- ================================================

-- Create clinics table
CREATE TABLE IF NOT EXISTS public.clinics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    clinic_name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address TEXT,
    phone_number TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_clinics_user_id ON public.clinics(user_id);
CREATE INDEX IF NOT EXISTS idx_clinics_location ON public.clinics(latitude, longitude);

-- Enable Row Level Security
ALTER TABLE public.clinics ENABLE ROW LEVEL SECURITY;

-- ================================================
-- RLS Policies for Clinics
-- ================================================

-- Allow everyone to view all clinics (for map display)
CREATE POLICY "Anyone can view clinics"
    ON public.clinics
    FOR SELECT
    USING (true);

-- Allow doctors to insert their own clinic
CREATE POLICY "Doctors can insert their own clinic"
    ON public.clinics
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'doctor'
        )
    );

-- Allow doctors to update their own clinic
CREATE POLICY "Doctors can update their own clinic"
    ON public.clinics
    FOR UPDATE
    USING (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'doctor'
        )
    )
    WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'doctor'
        )
    );

-- Allow doctors to delete their own clinic
CREATE POLICY "Doctors can delete their own clinic"
    ON public.clinics
    FOR DELETE
    USING (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'doctor'
        )
    );

-- Allow admins to manage all clinics
CREATE POLICY "Admins can manage all clinics"
    ON public.clinics
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- ================================================
-- Trigger to update updated_at timestamp
-- ================================================

CREATE OR REPLACE FUNCTION update_clinics_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_clinics_updated_at
    BEFORE UPDATE ON public.clinics
    FOR EACH ROW
    EXECUTE FUNCTION update_clinics_updated_at();

-- ================================================
-- Comments
-- ================================================

COMMENT ON TABLE public.clinics IS 'Stores clinic locations for doctors';
COMMENT ON COLUMN public.clinics.user_id IS 'Reference to the doctor user';
COMMENT ON COLUMN public.clinics.clinic_name IS 'Name of the clinic (usually doctor name)';
COMMENT ON COLUMN public.clinics.latitude IS 'Clinic latitude coordinate';
COMMENT ON COLUMN public.clinics.longitude IS 'Clinic longitude coordinate';
COMMENT ON COLUMN public.clinics.address IS 'Human-readable address from geocoding';
COMMENT ON COLUMN public.clinics.phone_number IS 'Clinic contact phone number';
