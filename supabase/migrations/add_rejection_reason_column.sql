-- Add rejection_reason column to users table if it doesn't exist
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS rejection_reason text;

-- Add comment to the column
COMMENT ON COLUMN public.users.rejection_reason IS 'Reason for rejecting the user account application';
