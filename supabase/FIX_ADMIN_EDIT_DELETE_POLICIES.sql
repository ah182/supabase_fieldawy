-- ============================================
-- Fix Admin Edit/Delete Policies
-- Allow admin users to edit/delete all records
-- ============================================

-- ============================================
-- 1. VET_SUPPLIES TABLE
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_update_all_vet_supplies" ON vet_supplies;
DROP POLICY IF EXISTS "admin_delete_all_vet_supplies" ON vet_supplies;

-- Admin can update all vet supplies
CREATE POLICY "admin_update_all_vet_supplies"
ON vet_supplies
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Admin can delete all vet supplies
CREATE POLICY "admin_delete_all_vet_supplies"
ON vet_supplies
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- 2. OFFERS TABLE
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_update_all_offers" ON offers;
DROP POLICY IF EXISTS "admin_delete_all_offers" ON offers;

-- Admin can update all offers
CREATE POLICY "admin_update_all_offers"
ON offers
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Admin can delete all offers
CREATE POLICY "admin_delete_all_offers"
ON offers
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- 3. DISTRIBUTOR_SURGICAL_TOOLS TABLE
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_update_all_surgical_tools" ON distributor_surgical_tools;
DROP POLICY IF EXISTS "admin_delete_all_surgical_tools" ON distributor_surgical_tools;

-- Admin can update all distributor surgical tools
CREATE POLICY "admin_update_all_surgical_tools"
ON distributor_surgical_tools
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Admin can delete all distributor surgical tools
CREATE POLICY "admin_delete_all_surgical_tools"
ON distributor_surgical_tools
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- 4. DISTRIBUTOR_OCR_PRODUCTS TABLE
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_update_all_ocr_products" ON distributor_ocr_products;
DROP POLICY IF EXISTS "admin_delete_all_ocr_products" ON distributor_ocr_products;

-- Admin can update all distributor OCR products
CREATE POLICY "admin_update_all_ocr_products"
ON distributor_ocr_products
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Admin can delete all distributor OCR products
CREATE POLICY "admin_delete_all_ocr_products"
ON distributor_ocr_products
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- 5. VET_BOOKS TABLE (for delete)
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_delete_all_books" ON vet_books;

-- Admin can delete all books
CREATE POLICY "admin_delete_all_books"
ON vet_books
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- 6. VET_COURSES TABLE (for delete)
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_delete_all_courses" ON vet_courses;

-- Admin can delete all courses
CREATE POLICY "admin_delete_all_courses"
ON vet_courses
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- 7. JOB_OFFERS TABLE (for delete)
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_delete_all_jobs" ON job_offers;

-- Admin can delete all job offers
CREATE POLICY "admin_delete_all_jobs"
ON job_offers
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- 11. PRODUCTS TABLE (Catalog Products)
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_update_all_products" ON products;
DROP POLICY IF EXISTS "admin_delete_all_products" ON products;

-- Admin can update all products
CREATE POLICY "admin_update_all_products"
ON products
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Admin can delete all products
CREATE POLICY "admin_delete_all_products"
ON products
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- 12. DISTRIBUTOR_PRODUCTS TABLE
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_update_all_distributor_products" ON distributor_products;
DROP POLICY IF EXISTS "admin_delete_all_distributor_products" ON distributor_products;

-- Admin can update all distributor products
CREATE POLICY "admin_update_all_distributor_products"
ON distributor_products
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Admin can delete all distributor products
CREATE POLICY "admin_delete_all_distributor_products"
ON distributor_products
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- VERIFICATION QUERY
-- Run this to check policies are created
-- ============================================

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE tablename IN (
    'vet_supplies',
    'offers',
    'distributor_surgical_tools',
    'distributor_ocr_products',
    'vet_books',
    'vet_courses',
    'job_offers',
    'products',
    'distributor_products'
)
AND policyname LIKE 'admin_%'
ORDER BY tablename, policyname;

-- ============================================
-- 8. VET_BOOKS TABLE (for update)
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_update_all_books" ON vet_books;

-- Admin can update all books
CREATE POLICY "admin_update_all_books"
ON vet_books
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- 9. VET_COURSES TABLE (for update)
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_update_all_courses" ON vet_courses;

-- Admin can update all courses
CREATE POLICY "admin_update_all_courses"
ON vet_courses
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- 10. JOB_OFFERS TABLE (for update)
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_update_all_jobs" ON job_offers;

-- Admin can update all job offers
CREATE POLICY "admin_update_all_jobs"
ON job_offers
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- TEST ADMIN USER
-- Check if your admin user has the correct role
-- ============================================

SELECT 
    id,
    email,
    display_name,
    role,
    account_status
FROM users
WHERE role = 'admin';

-- ============================================
-- NOTES
-- ============================================

/*
✅ These policies allow admin users to:
   - UPDATE any record in the tables
   - DELETE any record in the tables

⚠️ Make sure:
   1. Your admin user has role = 'admin' in the users table
   2. You are logged in with the admin account
   3. auth.uid() returns the admin user's ID

🔧 To apply:
   1. Copy this entire SQL
   2. Go to Supabase SQL Editor
   3. Paste and run
   4. Check verification query results
*/
