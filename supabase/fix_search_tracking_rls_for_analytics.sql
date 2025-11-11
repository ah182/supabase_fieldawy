-- إصلاح Row Level Security لجدول search_tracking
-- للسماح بقراءة البيانات الإحصائية (التوزيع الجغرافي والترندات) لجميع المستخدمين

-- حذف السياسة القديمة إذا كانت موجودة
DROP POLICY IF EXISTS "Users can view own search history" ON search_tracking;
DROP POLICY IF EXISTS "Allow authenticated users to read all search data for analytics" ON search_tracking;

-- سياسة جديدة: السماح لجميع المستخدمين المصادق عليهم بقراءة جميع بيانات البحث
-- للأغراض الإحصائية (الترندات، التوزيع الجغرافي، إلخ)
CREATE POLICY "Allow authenticated users to read all search data for analytics" ON search_tracking
    FOR SELECT 
    TO authenticated
    USING (true);  -- جميع المستخدمين المصادق عليهم يمكنهم القراءة

-- سياسة للإدراج: المستخدمون يمكنهم إدراج عمليات البحث الخاصة بهم فقط
-- (يجب أن تكون موجودة بالفعل، لكن نضيفها للتأكيد)
DROP POLICY IF EXISTS "Users can insert own searches" ON search_tracking;
CREATE POLICY "Users can insert own searches" ON search_tracking
    FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- سياسة للتحديث: المستخدمون يمكنهم تحديث عمليات البحث الخاصة بهم فقط
-- (يجب أن تكون موجودة بالفعل، لكن نضيفها للتأكيد)
DROP POLICY IF EXISTS "Users can update own searches" ON search_tracking;
CREATE POLICY "Users can update own searches" ON search_tracking
    FOR UPDATE 
    TO authenticated
    USING (auth.uid() = user_id);

-- التأكد من تفعيل RLS
ALTER TABLE search_tracking ENABLE ROW LEVEL SECURITY;

-- منح الصلاحيات
GRANT SELECT ON search_tracking TO authenticated;

-- رسالة نجاح
DO $$
BEGIN
    RAISE NOTICE '✅ تم إصلاح Row Level Security لجدول search_tracking';
    RAISE NOTICE '✅ جميع المستخدمين المصادق عليهم يمكنهم الآن قراءة البيانات الإحصائية';
END $$;
