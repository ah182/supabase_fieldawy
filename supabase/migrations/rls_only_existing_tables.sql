-- ============================================
-- Row Level Security (RLS) Policies
-- فقط للجداول الموجودة: surgical_tools, distributor_surgical_tools, offers
-- (بدون إنشاء جداول جديدة)
-- ============================================

-- ============================================
-- تنظيف: حذف السياسات القديمة إن وجدت
-- ============================================

-- surgical_tools
DROP POLICY IF EXISTS "Anyone can view surgical tools" ON surgical_tools;
DROP POLICY IF EXISTS "Authenticated users can insert surgical tools" ON surgical_tools;
DROP POLICY IF EXISTS "Users can update their surgical tools" ON surgical_tools;
DROP POLICY IF EXISTS "surgical_tools_select_authenticated" ON surgical_tools;
DROP POLICY IF EXISTS "surgical_tools_insert_authenticated" ON surgical_tools;
DROP POLICY IF EXISTS "surgical_tools_update_owner" ON surgical_tools;
DROP POLICY IF EXISTS "surgical_tools_delete_owner" ON surgical_tools;

-- distributor_surgical_tools
DROP POLICY IF EXISTS "Anyone can view distributor surgical tools" ON distributor_surgical_tools;
DROP POLICY IF EXISTS "Distributors can insert their tools" ON distributor_surgical_tools;
DROP POLICY IF EXISTS "Distributors can update their tools" ON distributor_surgical_tools;
DROP POLICY IF EXISTS "Distributors can delete their tools" ON distributor_surgical_tools;
DROP POLICY IF EXISTS "distributor_surgical_tools_select_authenticated" ON distributor_surgical_tools;
DROP POLICY IF EXISTS "distributor_surgical_tools_insert_owner" ON distributor_surgical_tools;
DROP POLICY IF EXISTS "distributor_surgical_tools_update_owner" ON distributor_surgical_tools;
DROP POLICY IF EXISTS "distributor_surgical_tools_delete_owner" ON distributor_surgical_tools;

-- offers
DROP POLICY IF EXISTS "offers_select_authenticated" ON offers;
DROP POLICY IF EXISTS "offers_insert_owner" ON offers;
DROP POLICY IF EXISTS "offers_update_owner" ON offers;
DROP POLICY IF EXISTS "offers_delete_owner" ON offers;

-- ============================================
-- 1️⃣ surgical_tools - RLS Policies
-- ============================================

ALTER TABLE surgical_tools ENABLE ROW LEVEL SECURITY;

-- القراءة: متاح للجميع المصادقين
CREATE POLICY "surgical_tools_select_authenticated"
ON surgical_tools
FOR SELECT
TO authenticated
USING (true);

-- الإضافة: المستخدم المصادق فقط
CREATE POLICY "surgical_tools_insert_authenticated"
ON surgical_tools
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = created_by);

-- التعديل: صاحب الأداة فقط
CREATE POLICY "surgical_tools_update_owner"
ON surgical_tools
FOR UPDATE
TO authenticated
USING (auth.uid() = created_by)
WITH CHECK (auth.uid() = created_by);

-- الحذف: صاحب الأداة فقط
CREATE POLICY "surgical_tools_delete_owner"
ON surgical_tools
FOR DELETE
TO authenticated
USING (auth.uid() = created_by);

-- ============================================
-- 2️⃣ distributor_surgical_tools - RLS Policies
-- ============================================

ALTER TABLE distributor_surgical_tools ENABLE ROW LEVEL SECURITY;

-- القراءة: متاح للجميع المصادقين
CREATE POLICY "distributor_surgical_tools_select_authenticated"
ON distributor_surgical_tools
FOR SELECT
TO authenticated
USING (true);

-- الإضافة: الموزع فقط
CREATE POLICY "distributor_surgical_tools_insert_owner"
ON distributor_surgical_tools
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = distributor_id);

-- التعديل: الموزع صاحب الأداة فقط
CREATE POLICY "distributor_surgical_tools_update_owner"
ON distributor_surgical_tools
FOR UPDATE
TO authenticated
USING (auth.uid() = distributor_id)
WITH CHECK (auth.uid() = distributor_id);

-- الحذف: الموزع صاحب الأداة فقط
CREATE POLICY "distributor_surgical_tools_delete_owner"
ON distributor_surgical_tools
FOR DELETE
TO authenticated
USING (auth.uid() = distributor_id);

-- ============================================
-- 3️⃣ offers - RLS Policies
-- ============================================

ALTER TABLE offers ENABLE ROW LEVEL SECURITY;

-- القراءة: متاح للجميع المصادقين
CREATE POLICY "offers_select_authenticated"
ON offers
FOR SELECT
TO authenticated
USING (true);

-- الإضافة: المستخدم فقط
CREATE POLICY "offers_insert_owner"
ON offers
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- التعديل: صاحب العرض فقط
CREATE POLICY "offers_update_owner"
ON offers
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- الحذف: صاحب العرض فقط
CREATE POLICY "offers_delete_owner"
ON offers
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ============================================
-- ✅ تم تطبيق RLS بنجاح
-- ============================================

/*
السياسات المطبقة:

✅ surgical_tools:
   - القراءة: جميع المصادقين
   - الإضافة/التعديل/الحذف: صاحب الأداة فقط

✅ distributor_surgical_tools:
   - القراءة: جميع المصادقين
   - الإضافة/التعديل/الحذف: الموزع صاحب الأداة فقط

✅ offers:
   - القراءة: جميع المصادقين
   - الإضافة/التعديل/الحذف: صاحب العرض فقط
*/
