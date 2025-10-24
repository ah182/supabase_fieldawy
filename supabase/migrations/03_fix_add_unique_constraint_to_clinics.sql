-- =========================================================
-- FIX: Add UNIQUE constraint to user_id in clinics table
-- This is required for the upsert_clinic function to work correctly.
-- The ON CONFLICT clause needs a unique constraint to detect conflicts.
-- =========================================================

ALTER TABLE public.clinics
ADD CONSTRAINT clinics_user_id_key UNIQUE (user_id);
