-- =====================================================
-- نظام جرد أدوية العيادة - Clinic Inventory System
-- =====================================================

-- جدول جرد العيادة الرئيسي
CREATE TABLE IF NOT EXISTS clinic_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- ربط بالمنتج الأصلي (catalog أو OCR)
    source_type TEXT NOT NULL DEFAULT 'manual', -- 'catalog', 'ocr', 'manual'
    source_product_id TEXT, -- product_id من الكتالوج
    source_ocr_product_id TEXT, -- ocr_product_id من OCR
    
    -- بيانات المنتج
    product_name TEXT NOT NULL,
    product_name_en TEXT,
    package TEXT NOT NULL, -- '100ml', '1kg', '500g'
    company TEXT,
    image_url TEXT,
    
    -- الكميات
    quantity INTEGER DEFAULT 0, -- عدد العلب الكاملة
    partial_quantity DECIMAL(10,2) DEFAULT 0, -- الكمية الجزئية المتبقية (بالملي أو الجرام)
    unit_type TEXT DEFAULT 'box', -- 'box', 'ml', 'gram', 'piece'
    unit_size DECIMAL(10,2) DEFAULT 1, -- حجم الوحدة الواحدة (100 لو 100ml)
    min_stock INTEGER DEFAULT 3, -- الحد الأدنى للتنبيه
    
    -- الأسعار
    purchase_price DECIMAL(10,2) NOT NULL, -- سعر الشراء للعلبة
    
    -- Metadata
    expiry_date DATE,
    batch_number TEXT,
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- جدول عمليات البيع والإضافة
CREATE TABLE IF NOT EXISTS clinic_inventory_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inventory_id UUID REFERENCES clinic_inventory(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id),
    
    transaction_type TEXT NOT NULL, -- 'add', 'sell', 'adjust', 'expired', 'return'
    transaction_date DATE DEFAULT CURRENT_DATE,
    
    -- بيانات المنتج (للعرض في التقارير)
    product_name TEXT,
    package TEXT,
    
    -- للإضافة
    boxes_added INTEGER DEFAULT 0,
    purchase_price_per_box DECIMAL(10,2),
    total_purchase_cost DECIMAL(10,2), -- boxes_added * purchase_price_per_box
    
    -- للبيع
    quantity_sold DECIMAL(10,2) DEFAULT 0, -- الكمية المباعة (بالوحدة)
    unit_sold TEXT, -- 'box', 'ml', 'gram', 'piece'
    selling_price DECIMAL(10,2), -- سعر البيع
    
    -- حسابات المكسب
    cost_of_sold DECIMAL(10,2), -- تكلفة الكمية المباعة
    profit DECIMAL(10,2), -- المكسب = selling_price - cost_of_sold
    
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_clinic_inventory_user ON clinic_inventory(user_id);
CREATE INDEX IF NOT EXISTS idx_clinic_inventory_active ON clinic_inventory(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_clinic_inv_trans_user ON clinic_inventory_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_clinic_inv_trans_date ON clinic_inventory_transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_clinic_inv_trans_type ON clinic_inventory_transactions(user_id, transaction_type, transaction_date);

-- RLS Policies
ALTER TABLE clinic_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic_inventory_transactions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users manage own inventory" ON clinic_inventory;
DROP POLICY IF EXISTS "Users view own transactions" ON clinic_inventory_transactions;

-- Create policies
CREATE POLICY "Users manage own inventory" ON clinic_inventory
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users view own transactions" ON clinic_inventory_transactions
    FOR ALL USING (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_clinic_inventory_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS clinic_inventory_updated_at ON clinic_inventory;
CREATE TRIGGER clinic_inventory_updated_at
    BEFORE UPDATE ON clinic_inventory
    FOR EACH ROW
    EXECUTE FUNCTION update_clinic_inventory_updated_at();

-- View for daily sales summary
CREATE OR REPLACE VIEW clinic_inventory_daily_summary AS
SELECT 
    user_id,
    transaction_date,
    -- إضافات
    COUNT(CASE WHEN transaction_type = 'add' THEN 1 END) as add_count,
    COALESCE(SUM(CASE WHEN transaction_type = 'add' THEN total_purchase_cost END), 0) as total_purchase,
    COALESCE(SUM(CASE WHEN transaction_type = 'add' THEN boxes_added END), 0) as total_boxes_added,
    -- مبيعات
    COUNT(CASE WHEN transaction_type = 'sell' THEN 1 END) as sell_count,
    COALESCE(SUM(CASE WHEN transaction_type = 'sell' THEN selling_price END), 0) as total_sales,
    COALESCE(SUM(CASE WHEN transaction_type = 'sell' THEN cost_of_sold END), 0) as total_cost,
    COALESCE(SUM(CASE WHEN transaction_type = 'sell' THEN profit END), 0) as total_profit
FROM clinic_inventory_transactions
GROUP BY user_id, transaction_date;
