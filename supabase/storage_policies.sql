-- Enable RLS on storage.objects is NOT needed (usually already enabled and requires superuser)
-- alter table storage.objects enable row level security;

-- ========================================================================================
-- Bucket: ocr
-- Content: Vet Supplies, Courses, Books, Surgical Tools, Products
-- Permissions: Public Read, Authenticated Write
-- ========================================================================================

-- Ensure bucket exists and is public
insert into storage.buckets (id, name, public)
values ('ocr', 'ocr', true)
on conflict (id) do update set public = true;

-- Policy: Public Read Access
create policy "Public Read Access for OCR"
on storage.objects for select
using ( bucket_id = 'ocr' );

-- Policy: Authenticated Insert Access
create policy "Authenticated Insert for OCR"
on storage.objects for insert
to authenticated
with check ( bucket_id = 'ocr' );

-- Policy: Authenticated Update Access
create policy "Authenticated Update for OCR"
on storage.objects for update
to authenticated
using ( bucket_id = 'ocr' );

-- Policy: Authenticated Delete Access
create policy "Authenticated Delete for OCR"
on storage.objects for delete
to authenticated
using ( bucket_id = 'ocr' );


-- ========================================================================================
-- Bucket: stories
-- Content: Distributor Stories
-- Permissions: Public Read, Authenticated Write
-- ========================================================================================

-- Ensure bucket exists and is public
insert into storage.buckets (id, name, public)
values ('stories', 'stories', true)
on conflict (id) do update set public = true;

-- Policy: Public Read Access
create policy "Public Read Access for Stories"
on storage.objects for select
using ( bucket_id = 'stories' );

-- Policy: Authenticated Write Access (Distributors)
create policy "Authenticated Insert for Stories"
on storage.objects for insert
to authenticated
with check ( bucket_id = 'stories' );

create policy "Authenticated Update for Stories"
on storage.objects for update
to authenticated
using ( bucket_id = 'stories' );

create policy "Authenticated Delete for Stories"
on storage.objects for delete
to authenticated
using ( bucket_id = 'stories' );


-- ========================================================================================
-- Bucket: docs&profiles
-- Content: User Profile Photos, Identity Documents
-- Permissions: 
--   - Photos: Public Read (to simplify displaying avatars)
--   - Documents: Private Read (Only Owner/Admin) - *Requires stricter logic*
-- ========================================================================================

-- Ensure bucket exists (Note: 'docs&profiles' might need special handling if created via UI with different casing, assuming exact match)
-- We set public = false initially because 'documents' should be private. We can allow public access to 'photos' via policy.
insert into storage.buckets (id, name, public)
values ('docs&profiles', 'docs&profiles', false)
on conflict (id) do nothing;

-- Policy: Public Read for Photos ONLY
create policy "Public Read for Profile Photos"
on storage.objects for select
using ( bucket_id = 'docs&profiles' and (storage.foldername(name))[1] = 'photos' );

-- Policy: Private Read for Documents (Owner or Admin)
-- Assumes file path convention: documents/USERID_filename
-- Logic: User ID is part of filename OR user is admin
create policy "Individual Read Access for Documents"
on storage.objects for select
to authenticated
using ( 
  bucket_id = 'docs&profiles' 
  and (storage.foldername(name))[1] = 'documents' 
  and (
    -- Allow if user is admin (check public.users table or jwt claim)
    (select role from public.users where id = auth.uid()) = 'admin'
    OR
    -- Allow if filename starts with user ID (weak check but common in storage patterns)
    -- Better: Match path owner convention if strictly enforced
    name like 'documents/' || auth.uid() || '_%'
  )
);

-- Policy: Authenticated Insert (Users can upload their own files)
create policy "Authenticated Insert for Docs & Profiles"
on storage.objects for insert
to authenticated
with check ( 
  bucket_id = 'docs&profiles' 
  and (
     -- Enforce path convention: folder/USERID_...
     name like 'photos/' || auth.uid() || '_%'
     OR
     name like 'documents/' || auth.uid() || '_%'
  )
);

-- Policy: Users can update/delete their own files
create policy "Individual Update/Delete for Docs & Profiles"
on storage.objects for delete
to authenticated
using ( 
  bucket_id = 'docs&profiles'
  and (
     name like 'photos/' || auth.uid() || '_%'
     OR
     name like 'documents/' || auth.uid() || '_%'
  )
);
