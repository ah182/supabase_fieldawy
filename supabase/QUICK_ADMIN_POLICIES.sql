-- ============================================
-- QUICK FIX: Admin Edit/Delete Policies
-- انسخ كل الكود ده والصقه في Supabase SQL Editor
-- ============================================

-- 1. Vet Supplies
DROP POLICY IF EXISTS "admin_update_all_vet_supplies" ON vet_supplies;
CREATE POLICY "admin_update_all_vet_supplies" ON vet_supplies FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin_delete_all_vet_supplies" ON vet_supplies;
CREATE POLICY "admin_delete_all_vet_supplies" ON vet_supplies FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- 2. Offers
DROP POLICY IF EXISTS "admin_update_all_offers" ON offers;
CREATE POLICY "admin_update_all_offers" ON offers FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin_delete_all_offers" ON offers;
CREATE POLICY "admin_delete_all_offers" ON offers FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- 3. Surgical Tools
DROP POLICY IF EXISTS "admin_update_all_surgical_tools" ON distributor_surgical_tools;
CREATE POLICY "admin_update_all_surgical_tools" ON distributor_surgical_tools FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin_delete_all_surgical_tools" ON distributor_surgical_tools;
CREATE POLICY "admin_delete_all_surgical_tools" ON distributor_surgical_tools FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- 4. OCR Products
DROP POLICY IF EXISTS "admin_update_all_ocr_products" ON distributor_ocr_products;
CREATE POLICY "admin_update_all_ocr_products" ON distributor_ocr_products FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin_delete_all_ocr_products" ON distributor_ocr_products;
CREATE POLICY "admin_delete_all_ocr_products" ON distributor_ocr_products FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- 5. Books
DROP POLICY IF EXISTS "admin_update_all_books" ON vet_books;
CREATE POLICY "admin_update_all_books" ON vet_books FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin_delete_all_books" ON vet_books;
CREATE POLICY "admin_delete_all_books" ON vet_books FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- 6. Courses
DROP POLICY IF EXISTS "admin_update_all_courses" ON vet_courses;
CREATE POLICY "admin_update_all_courses" ON vet_courses FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin_delete_all_courses" ON vet_courses;
CREATE POLICY "admin_delete_all_courses" ON vet_courses FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- 7. Job Offers
DROP POLICY IF EXISTS "admin_update_all_jobs" ON job_offers;
CREATE POLICY "admin_update_all_jobs" ON job_offers FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin_delete_all_jobs" ON job_offers;
CREATE POLICY "admin_delete_all_jobs" ON job_offers FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- 8. Products (Catalog)
DROP POLICY IF EXISTS "admin_update_all_products" ON products;
CREATE POLICY "admin_update_all_products" ON products FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin_delete_all_products" ON products;
CREATE POLICY "admin_delete_all_products" ON products FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- 9. Distributor Products
DROP POLICY IF EXISTS "admin_update_all_distributor_products" ON distributor_products;
CREATE POLICY "admin_update_all_distributor_products" ON distributor_products FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin_delete_all_distributor_products" ON distributor_products;
CREATE POLICY "admin_delete_all_distributor_products" ON distributor_products FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ============================================
-- التحقق من نجاح العملية
-- ============================================
SELECT 
    tablename,
    policyname,
    cmd
FROM pg_policies 
WHERE (policyname LIKE 'admin_update%' OR policyname LIKE 'admin_delete%')
ORDER BY tablename, policyname;

-- ============================================
-- التحقق من admin user
-- ============================================
SELECT id, email, role, account_status 
FROM users 
WHERE role = 'admin';

-- إذا لم يكن موجود أو البيانات خطأ، شغّل:
-- UPDATE users SET role = 'admin', account_status = 'approved' WHERE email = 'admin@fieldawy.com';
