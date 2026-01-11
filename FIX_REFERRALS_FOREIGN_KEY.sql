-- Fix for: Unable to delete rows as one of them is currently referenced by a foreign key constraint from the table referrals

-- 1. Drop the existing constraint if it exists (using the name from the error message)
ALTER TABLE public.referrals
DROP CONSTRAINT IF EXISTS referrals_invited_id_fkey;

-- 2. Drop the constraint named 'fk_invited' if it exists (just in case)
ALTER TABLE public.referrals
DROP CONSTRAINT IF EXISTS fk_invited;

-- 3. Re-add the constraint with ON DELETE CASCADE
ALTER TABLE public.referrals
ADD CONSTRAINT referrals_invited_id_fkey
    FOREIGN KEY (invited_id)
    REFERENCES public.users(id)
    ON DELETE CASCADE;

-- Optional: Ensure the inviter constraint is also set correctly (ON DELETE SET NULL as per original design)
ALTER TABLE public.referrals
DROP CONSTRAINT IF EXISTS referrals_inviter_id_fkey;

ALTER TABLE public.referrals
DROP CONSTRAINT IF EXISTS fk_inviter;

ALTER TABLE public.referrals
ADD CONSTRAINT referrals_inviter_id_fkey
    FOREIGN KEY (inviter_id)
    REFERENCES public.users(id)
    ON DELETE SET NULL;
