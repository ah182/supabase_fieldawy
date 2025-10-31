-- ==========================================
-- جدول تعليقات الأدوات الجراحية
-- ==========================================
CREATE TABLE IF NOT EXISTS surgical_tool_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    distributor_surgical_tool_id UUID NOT NULL REFERENCES distributor_surgical_tools(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
); 

-- ==========================================
-- إنشاء Indexes لتحسين الأداء
-- ==========================================
CREATE INDEX IF NOT EXISTS idx_surgical_tool_comments_distributor_surgical_tool_id ON surgical_tool_comments(distributor_surgical_tool_id);
CREATE INDEX IF NOT EXISTS idx_surgical_tool_comments_user_id ON surgical_tool_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_surgical_tool_comments_created_at ON surgical_tool_comments(created_at DESC);

-- ==========================================
-- تفعيل RLS (Row Level Security)
-- ==========================================
ALTER TABLE surgical_tool_comments ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- Policies لتعليقات الأدوات الجراحية
-- ==========================================

-- السماح للجميع بقراءة التعليقات
CREATE POLICY "السماح للجميع بقراءة تعليقات الأدوات الجراحية"
ON surgical_tool_comments FOR SELECT
TO authenticated
USING (true);

-- السماح للمستخدمين المسجلين بإضافة تعليقات
CREATE POLICY "السماح للمستخدمين المسجلين بإضافة تعليقات الأدوات الجراحية"
ON surgical_tool_comments FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- السماح للمستخدم بحذف تعليقاته فقط
CREATE POLICY "السماح للمستخدم بحذف تعليقاته على الأدوات الجراحية"
ON surgical_tool_comments FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- السماح للمستخدم بتعديل تعليقاته فقط
CREATE POLICY "السماح للمستخدم بتعديل تعليقاته على الأدوات الجراحية"
ON surgical_tool_comments FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ==========================================
-- Functions لحساب عدد التعليقات
-- ==========================================

DROP FUNCTION IF EXISTS get_surgical_tool_comments_count(uuid);
-- دالة لحساب عدد تعليقات الأداة الجراحية
CREATE OR REPLACE FUNCTION get_surgical_tool_comments_count(p_distributor_surgical_tool_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM surgical_tool_comments WHERE distributor_surgical_tool_id = p_distributor_surgical_tool_id);
END;
$$ LANGUAGE plpgsql STABLE;

-- ==========================================
-- إضافة عمود comments_count للأدوات الجراحية (اختياري للكاش)
-- ==========================================

-- إضافة عمود للأدوات الجراحية إذا لم يكن موجوداً
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'distributor_surgical_tools' AND column_name = 'comments_count'
    ) THEN
        ALTER TABLE distributor_surgical_tools ADD COLUMN comments_count INTEGER DEFAULT 0;
    END IF;
END $$;

-- ==========================================
-- Triggers لتحديث عداد التعليقات تلقائياً
-- ==========================================

-- Function لتحديث عداد تعليقات الأداة الجراحية
CREATE OR REPLACE FUNCTION update_surgical_tool_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE distributor_surgical_tools SET comments_count = comments_count + 1 WHERE id = NEW.distributor_surgical_tool_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE distributor_surgical_tools SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = OLD.distributor_surgical_tool_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger لتحديث عداد تعليقات الأداة الجراحية
DROP TRIGGER IF EXISTS trigger_update_surgical_tool_comments_count ON surgical_tool_comments;
CREATE TRIGGER trigger_update_surgical_tool_comments_count
AFTER INSERT OR DELETE ON surgical_tool_comments
FOR EACH ROW EXECUTE FUNCTION update_surgical_tool_comments_count();