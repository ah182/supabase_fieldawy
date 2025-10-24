-- ============================================
-- ADMIN EDIT/DELETE POLICIES
-- تطبيق صلاحيات التعديل والحذف للأدمن على جميع الجداول
-- ============================================

-- ============================================
-- BOOKS (vet_books)
-- ============================================
DROP POLICY IF EXISTS "admin_update_all_books" ON vet_books;
CREATE POLICY "admin_update_all_books" ON vet_books FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ============================================
-- COURSES (vet_courses)
-- ============================================
DROP POLICY IF EXISTS "admin_update_all_courses" ON vet_courses;
CREATE POLICY "admin_update_all_courses" ON vet_courses FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ============================================
-- JOBS (job_offers)
-- ============================================
DROP POLICY IF EXISTS "admin_update_all_jobs" ON job_offers;
CREATE POLICY "admin_update_all_jobs" ON job_offers FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ============================================
-- CATALOG PRODUCTS (products)
-- ============================================
DROP POLICY IF EXISTS "admin_update_all_products" ON products;
CREATE POLICY "admin_update_all_products" ON products FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin_delete_all_products" ON products;
CREATE POLICY "admin_delete_all_products" ON products FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ============================================
-- DISTRIBUTOR PRODUCTS (distributor_products)
-- ============================================
DROP POLICY IF EXISTS "admin_update_all_distributor_products" ON distributor_products;
CREATE POLICY "admin_update_all_distributor_products" ON distributor_products FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin_delete_all_distributor_products" ON distributor_products;
CREATE POLICY "admin_delete_all_distributor_products" ON distributor_products FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ============================================
-- VET SUPPLIES (vet_supplies)
-- ============================================
DROP POLICY IF EXISTS "admin_update_all_vet_supplies" ON vet_supplies;
CREATE POLICY "admin_update_all_vet_supplies" ON vet_supplies FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ============================================
-- OFFERS (offers)
-- ============================================
DROP POLICY IF EXISTS "admin_update_all_offers" ON offers;
CREATE POLICY "admin_update_all_offers" ON offers FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ============================================
-- SURGICAL TOOLS (distributor_surgical_tools)
-- ============================================
DROP POLICY IF EXISTS "admin_update_all_surgical_tools" ON distributor_surgical_tools;
CREATE POLICY "admin_update_all_surgical_tools" ON distributor_surgical_tools FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ============================================
-- OCR PRODUCTS (distributor_ocr_products)
-- ============================================
DROP POLICY IF EXISTS "admin_update_all_ocr_products" ON distributor_ocr_products;
CREATE POLICY "admin_update_all_ocr_products" ON distributor_ocr_products FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ============================================
-- التحقق من نجاح العملية
-- ============================================
SELECT 
    tablename, 
    policyname, 
    cmd,
    qual
FROM pg_policies 
WHERE policyname LIKE 'admin_update%' OR policyname LIKE 'admin_delete%'
ORDER BY tablename, policyname;

-- ============================================
-- التحقق من صلاحيات الأدمن
-- ============================================
-- تأكد من أن حساب الأدمن لديه الصلاحيات الصحيحة:
SELECT id, email, role, account_status 
FROM users 
WHERE email = 'admin@fieldawy.com';

-- إذا لم يكن الحساب موجود أو غير صحيح، قم بتحديثه:
-- UPDATE users 
-- SET role = 'admin', account_status = 'approved' 
-- WHERE email = 'admin@fieldawy.com';
