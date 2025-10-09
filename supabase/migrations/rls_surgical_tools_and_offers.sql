-- ============================================
-- Row Level Security (RLS) Policies
-- للجداول: surgical_tools, distributor_surgical_tools, offers
-- ============================================

-- ============================================
-- 1️⃣ جدول surgical_tools (كتالوج الأدوات الجراحية)
-- ============================================

-- تفعيل RLS على الجدول
ALTER TABLE surgical_tools ENABLE ROW LEVEL SECURITY;

-- 🔓 سياسة القراءة: السماح للجميع (المصادقين) بقراءة كتالوج الأدوات
CREATE POLICY "surgical_tools_select_authenticated"
ON surgical_tools
FOR SELECT
TO authenticated
USING (true);

-- ✍️ سياسة الإضافة: السماح للمستخدمين المصادقين بإضافة أدوات جديدة
CREATE POLICY "surgical_tools_insert_authenticated"
ON surgical_tools
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = created_by);

-- 📝 سياسة التعديل: المستخدم يمكنه تعديل الأدوات التي أضافها فقط
CREATE POLICY "surgical_tools_update_owner"
ON surgical_tools
FOR UPDATE
TO authenticated
USING (auth.uid() = created_by)
WITH CHECK (auth.uid() = created_by);

-- 🗑️ سياسة الحذف: المستخدم يمكنه حذف الأدوات التي أضافها فقط
CREATE POLICY "surgical_tools_delete_owner"
ON surgical_tools
FOR DELETE
TO authenticated
USING (auth.uid() = created_by);

-- ============================================
-- 2️⃣ جدول distributor_surgical_tools (أدوات الموزعين)
-- ============================================

-- تفعيل RLS على الجدول
ALTER TABLE distributor_surgical_tools ENABLE ROW LEVEL SECURITY;

-- 🔓 سياسة القراءة: السماح للجميع (المصادقين) بقراءة أدوات جميع الموزعين
CREATE POLICY "distributor_surgical_tools_select_authenticated"
ON distributor_surgical_tools
FOR SELECT
TO authenticated
USING (true);

-- ✍️ سياسة الإضافة: الموزع يمكنه إضافة أدواته فقط
CREATE POLICY "distributor_surgical_tools_insert_owner"
ON distributor_surgical_tools
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = distributor_id);

-- 📝 سياسة التعديل: الموزع يمكنه تعديل أدواته فقط
CREATE POLICY "distributor_surgical_tools_update_owner"
ON distributor_surgical_tools
FOR UPDATE
TO authenticated
USING (auth.uid() = distributor_id)
WITH CHECK (auth.uid() = distributor_id);

-- 🗑️ سياسة الحذف: الموزع يمكنه حذف أدواته فقط
CREATE POLICY "distributor_surgical_tools_delete_owner"
ON distributor_surgical_tools
FOR DELETE
TO authenticated
USING (auth.uid() = distributor_id);

-- ============================================
-- 3️⃣ جدول offers (العروض)
-- ============================================

-- إنشاء الجدول إذا لم يكن موجوداً
CREATE TABLE IF NOT EXISTS offers (
  id uuid primary key default gen_random_uuid(),
  product_id text not null,                      -- معرف المنتج (من products أو ocr_products)
  is_ocr boolean not null default false,         -- هل المنتج من OCR أم من الكتالوج
  user_id uuid not null references auth.users(id) on delete cascade,
  price numeric(12,2) not null check (price >= 0),
  expiration_date timestamptz not null,          -- تاريخ انتهاء العرض
  description text,                               -- وصف العرض (اختياري)
  package text,                                   -- العبوة المختارة
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Index للأداء
CREATE INDEX IF NOT EXISTS idx_offers_user_id ON offers(user_id);
CREATE INDEX IF NOT EXISTS idx_offers_product_id ON offers(product_id);
CREATE INDEX IF NOT EXISTS idx_offers_expiration_date ON offers(expiration_date);
CREATE INDEX IF NOT EXISTS idx_offers_created_at ON offers(created_at DESC);

-- تفعيل RLS على الجدول
ALTER TABLE offers ENABLE ROW LEVEL SECURITY;

-- 🔓 سياسة القراءة: السماح للجميع (المصادقين) بقراءة جميع العروض
CREATE POLICY "offers_select_authenticated"
ON offers
FOR SELECT
TO authenticated
USING (true);

-- ✍️ سياسة الإضافة: المستخدم يمكنه إضافة عروضه فقط
CREATE POLICY "offers_insert_owner"
ON offers
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 📝 سياسة التعديل: المستخدم يمكنه تعديل عروضه فقط
CREATE POLICY "offers_update_owner"
ON offers
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 🗑️ سياسة الحذف: المستخدم يمكنه حذف عروضه فقط
CREATE POLICY "offers_delete_owner"
ON offers
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ============================================
-- Trigger لتحديث updated_at تلقائياً في offers
-- ============================================

CREATE OR REPLACE FUNCTION update_offers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_offers_updated_at_trigger
    BEFORE UPDATE ON offers
    FOR EACH ROW
    EXECUTE FUNCTION update_offers_updated_at();

-- ============================================
-- دالة لحذف العروض المنتهية (مضى على إنشائها أكثر من 7 أيام)
-- ============================================

CREATE OR REPLACE FUNCTION cleanup_old_offers()
RETURNS void AS $$
BEGIN
  DELETE FROM offers
  WHERE created_at < (NOW() - INTERVAL '7 days');
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ملاحظات
-- ============================================

/*
✅ جميع الجداول الآن محمية بـ RLS
✅ المستخدمون يمكنهم القراءة من جميع الجداول (للعرض في التطبيق)
✅ المستخدمون يمكنهم الكتابة/التعديل/الحذف فقط في بياناتهم الخاصة
✅ الحماية الكاملة من الوصول غير المصرح به

📝 لتطبيق هذه السياسات على قاعدة البيانات، قم بتشغيل:
   supabase db push

أو نسخ المحتوى في Supabase SQL Editor وتشغيله مباشرة
*/
