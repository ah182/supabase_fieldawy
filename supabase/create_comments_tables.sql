-- ==========================================
-- جدول تعليقات الكورسات
-- ==========================================
CREATE TABLE IF NOT EXISTS course_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    course_id UUID NOT NULL REFERENCES vet_courses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==========================================
-- جدول تعليقات الكتب
-- ==========================================
CREATE TABLE IF NOT EXISTS book_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    book_id UUID NOT NULL REFERENCES vet_books(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==========================================
-- إنشاء Indexes لتحسين الأداء
-- ==========================================
CREATE INDEX IF NOT EXISTS idx_course_comments_course_id ON course_comments(course_id);
CREATE INDEX IF NOT EXISTS idx_course_comments_user_id ON course_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_course_comments_created_at ON course_comments(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_book_comments_book_id ON book_comments(book_id);
CREATE INDEX IF NOT EXISTS idx_book_comments_user_id ON book_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_book_comments_created_at ON book_comments(created_at DESC);

-- ==========================================
-- تفعيل RLS (Row Level Security)
-- ==========================================
ALTER TABLE course_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE book_comments ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- Policies لتعليقات الكورسات
-- ==========================================

-- السماح للجميع بقراءة التعليقات
CREATE POLICY "السماح للجميع بقراءة تعليقات الكورسات"
ON course_comments FOR SELECT
TO authenticated
USING (true);

-- السماح للمستخدمين المسجلين بإضافة تعليقات
CREATE POLICY "السماح للمستخدمين المسجلين بإضافة تعليقات الكورسات"
ON course_comments FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- السماح للمستخدم بحذف تعليقاته فقط
CREATE POLICY "السماح للمستخدم بحذف تعليقاته على الكورسات"
ON course_comments FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- السماح للمستخدم بتعديل تعليقاته فقط
CREATE POLICY "السماح للمستخدم بتعديل تعليقاته على الكورسات"
ON course_comments FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ==========================================
-- Policies لتعليقات الكتب
-- ==========================================

-- السماح للجميع بقراءة التعليقات
CREATE POLICY "السماح للجميع بقراءة تعليقات الكتب"
ON book_comments FOR SELECT
TO authenticated
USING (true);

-- السماح للمستخدمين المسجلين بإضافة تعليقات
CREATE POLICY "السماح للمستخدمين المسجلين بإضافة تعليقات الكتب"
ON book_comments FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- السماح للمستخدم بحذف تعليقاته فقط
CREATE POLICY "السماح للمستخدم بحذف تعليقاته على الكتب"
ON book_comments FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- السماح للمستخدم بتعديل تعليقاته فقط
CREATE POLICY "السماح للمستخدم بتعديل تعليقاته على الكتب"
ON book_comments FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ==========================================
-- Functions لحساب عدد التعليقات
-- ==========================================

-- دالة لحساب عدد تعليقات الكورس
CREATE OR REPLACE FUNCTION get_course_comments_count(p_course_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM course_comments WHERE course_id = p_course_id);
END;
$$ LANGUAGE plpgsql STABLE;

-- دالة لحساب عدد تعليقات الكتاب
CREATE OR REPLACE FUNCTION get_book_comments_count(p_book_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM book_comments WHERE book_id = p_book_id);
END;
$$ LANGUAGE plpgsql STABLE;

-- ==========================================
-- إضافة عمود comments_count للكورسات والكتب (اختياري للكاش)
-- ==========================================

-- إضافة عمود للكورسات إذا لم يكن موجوداً
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vet_courses' AND column_name = 'comments_count'
    ) THEN
        ALTER TABLE vet_courses ADD COLUMN comments_count INTEGER DEFAULT 0;
    END IF;
END $$;

-- إضافة عمود للكتب إذا لم يكن موجوداً
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'vet_books' AND column_name = 'comments_count'
    ) THEN
        ALTER TABLE vet_books ADD COLUMN comments_count INTEGER DEFAULT 0;
    END IF;
END $$;

-- ==========================================
-- Triggers لتحديث عداد التعليقات تلقائياً
-- ==========================================

-- Function لتحديث عداد تعليقات الكورس
CREATE OR REPLACE FUNCTION update_course_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE vet_courses SET comments_count = comments_count + 1 WHERE id = NEW.course_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE vet_courses SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = OLD.course_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger لتحديث عداد تعليقات الكورس
DROP TRIGGER IF EXISTS trigger_update_course_comments_count ON course_comments;
CREATE TRIGGER trigger_update_course_comments_count
AFTER INSERT OR DELETE ON course_comments
FOR EACH ROW EXECUTE FUNCTION update_course_comments_count();

-- Function لتحديث عداد تعليقات الكتاب
CREATE OR REPLACE FUNCTION update_book_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE vet_books SET comments_count = comments_count + 1 WHERE id = NEW.book_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE vet_books SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = OLD.book_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger لتحديث عداد تعليقات الكتاب
DROP TRIGGER IF EXISTS trigger_update_book_comments_count ON book_comments;
CREATE TRIGGER trigger_update_book_comments_count
AFTER INSERT OR DELETE ON book_comments
FOR EACH ROW EXECUTE FUNCTION update_book_comments_count();
