-- ============================================
-- جداول الأدوات الجراحية (Surgical Tools)
-- ============================================

-- 1️⃣ جدول الأدوات الجراحية العامة (Catalog)
-- يحتوي على معلومات الأداة الأساسية التي يمكن مشاركتها بين الموزعين
CREATE TABLE surgical_tools (
  id uuid primary key default gen_random_uuid(),
  tool_name text not null,                    -- اسم الأداة (إجباري)
  company text,                                -- الشركة المصنعة (اختياري)
  image_url text,                              -- رابط صورة الأداة على Cloudinary
  created_by uuid references auth.users(id),   -- من أضاف الأداة أول مرة
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2️⃣ جدول ربط الموزعين بالأدوات الجراحية
-- كل موزع له سعره ووصفه الخاص للأداة
CREATE TABLE distributor_surgical_tools (
  id uuid primary key default gen_random_uuid(),
  distributor_id uuid not null references auth.users(id) on delete cascade,
  distributor_name text not null,                                            -- اسم الموزع (للعرض السريع)
  surgical_tool_id uuid not null references surgical_tools(id) on delete cascade,
  description text not null,                                                 -- وصف الأداة من الموزع (إجباري) ⭐
  price numeric(12,2) not null check (price >= 0),                          -- سعر الأداة عند هذا الموزع (إجباري) ⭐
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  
  -- منع التكرار: نفس الموزع لا يمكنه إضافة نفس الأداة مرتين
  unique(distributor_id, surgical_tool_id)
);

-- ============================================
-- Indexes للأداء والبحث السريع
-- ============================================

-- البحث في الأدوات
CREATE INDEX idx_surgical_tools_name ON surgical_tools USING gin(to_tsvector('english', tool_name));
CREATE INDEX idx_surgical_tools_company ON surgical_tools(company) WHERE company IS NOT NULL;
CREATE INDEX idx_surgical_tools_created_at ON surgical_tools(created_at DESC);

-- البحث في أدوات الموزعين
CREATE INDEX idx_distributor_surgical_tools_distributor ON distributor_surgical_tools(distributor_id);
CREATE INDEX idx_distributor_surgical_tools_tool ON distributor_surgical_tools(surgical_tool_id);
-- Full-text search على الوصف
CREATE INDEX idx_distributor_surgical_tools_description ON distributor_surgical_tools USING gin(to_tsvector('english', description));

-- ============================================
-- Row Level Security (RLS) Policies
-- ============================================

-- تفعيل RLS
ALTER TABLE surgical_tools ENABLE ROW LEVEL SECURITY;
ALTER TABLE distributor_surgical_tools ENABLE ROW LEVEL SECURITY;

-- السماح للجميع بقراءة كتالوج الأدوات
CREATE POLICY "Anyone can view surgical tools" 
  ON surgical_tools FOR SELECT 
  USING (true);

-- السماح للمستخدمين المسجلين بإضافة أدوات جديدة
CREATE POLICY "Authenticated users can insert surgical tools" 
  ON surgical_tools FOR INSERT 
  WITH CHECK (auth.uid() = created_by);

-- السماح للمستخدمين بتعديل الأدوات التي أضافوها
CREATE POLICY "Users can update their surgical tools" 
  ON surgical_tools FOR UPDATE 
  USING (auth.uid() = created_by);

-- السماح للجميع بقراءة أدوات الموزعين (للعرض في الكتالوج)
CREATE POLICY "Anyone can view distributor surgical tools" 
  ON distributor_surgical_tools FOR SELECT 
  USING (true);

-- السماح للموزعين بإضافة أدواتهم فقط
CREATE POLICY "Distributors can insert their tools" 
  ON distributor_surgical_tools FOR INSERT 
  WITH CHECK (auth.uid() = distributor_id);

-- السماح للموزعين بتعديل أدواتهم فقط
CREATE POLICY "Distributors can update their tools" 
  ON distributor_surgical_tools FOR UPDATE 
  USING (auth.uid() = distributor_id);

-- السماح للموزعين بحذف أدواتهم فقط
CREATE POLICY "Distributors can delete their tools" 
  ON distributor_surgical_tools FOR DELETE 
  USING (auth.uid() = distributor_id);

-- ============================================
-- Triggers للتحديث التلقائي
-- ============================================

-- تحديث updated_at تلقائياً
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_surgical_tools_updated_at
    BEFORE UPDATE ON surgical_tools
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_distributor_surgical_tools_updated_at
    BEFORE UPDATE ON distributor_surgical_tools
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- دوال مساعدة (Helper Functions)
-- ============================================

-- دالة للحصول على أدوات موزع معين مع التفاصيل الكاملة
CREATE OR REPLACE FUNCTION get_distributor_surgical_tools(dist_id uuid)
RETURNS TABLE (
  id uuid,
  tool_name text,
  company text,
  description text,
  image_url text,
  price numeric,
  created_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dst.id,
    st.tool_name,
    st.company,
    dst.description,              -- الوصف من جدول الموزع ⭐
    st.image_url,
    dst.price,
    dst.created_at
  FROM distributor_surgical_tools dst
  JOIN surgical_tools st ON dst.surgical_tool_id = st.id
  WHERE dst.distributor_id = dist_id
  ORDER BY dst.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- دالة للبحث في أدوات جميع الموزعين
CREATE OR REPLACE FUNCTION search_surgical_tools(search_query text)
RETURNS TABLE (
  id uuid,
  tool_name text,
  company text,
  description text,
  image_url text,
  price numeric,
  distributor_name text,
  distributor_id uuid
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dst.id,
    st.tool_name,
    st.company,
    dst.description,
    st.image_url,
    dst.price,
    dst.distributor_name,
    dst.distributor_id
  FROM distributor_surgical_tools dst
  JOIN surgical_tools st ON dst.surgical_tool_id = st.id
  WHERE 
    st.tool_name ILIKE '%' || search_query || '%'
    OR st.company ILIKE '%' || search_query || '%'
    OR dst.description ILIKE '%' || search_query || '%'
  ORDER BY dst.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- بيانات تجريبية (Optional)
-- ============================================

-- يمكنك حذف هذا القسم في الإنتاج
/*
-- إضافة أداة للكتالوج العام
INSERT INTO surgical_tools (tool_name, company, image_url, created_by) VALUES
('Surgical Scissors', 'MedTech Pro', 'https://example.com/scissors.jpg', auth.uid());

-- ربطها بموزع مع وصفه الخاص
INSERT INTO distributor_surgical_tools (
  distributor_id, 
  distributor_name, 
  surgical_tool_id, 
  description, 
  price
) VALUES (
  auth.uid(),
  'Distributor Name',
  (SELECT id FROM surgical_tools WHERE tool_name = 'Surgical Scissors' LIMIT 1),
  'High-quality stainless steel surgical scissors. Perfect for precise cutting in veterinary procedures. Comes with lifetime warranty.',
  150.00
);
*/
