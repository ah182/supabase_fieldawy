-- 1. Create the helper function to login assistant and set claim
CREATE OR REPLACE FUNCTION login_clinic_assistant(code_input TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    found_user_id UUID;
BEGIN
    -- Find the doctor
    SELECT id INTO found_user_id 
    FROM public.users
    WHERE clinic_access_code = code_input
    LIMIT 1;

    IF found_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid Code');
    END IF;

    -- Update the CURRENT USER's metadata to link them to the doctor
    UPDATE auth.users
    SET raw_user_meta_data = 
        COALESCE(raw_user_meta_data, '{}'::jsonb) || 
        jsonb_build_object('assistant_target_id', found_user_id)
    WHERE id = auth.uid();

    RETURN jsonb_build_object('success', true, 'target_user_id', found_user_id);
END;
$$;

-- 2. Create the missing 'clinic_inventory_reports' table if it doesn't exist
CREATE TABLE IF NOT EXISTS clinic_inventory_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    
    report_type TEXT NOT NULL, -- 'daily', 'weekly', 'monthly'
    report_date DATE NOT NULL, -- Date or start of period
    
    -- Add Totals
    total_added_count INTEGER DEFAULT 0,
    total_purchase_amount DECIMAL(10,2) DEFAULT 0,
    
    -- Sell Totals
    total_sold_count INTEGER DEFAULT 0,
    total_selling_amount DECIMAL(10,2) DEFAULT 0,
    total_cost_amount DECIMAL(10,2) DEFAULT 0,
    total_profit DECIMAL(10,2) DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, report_type, report_date)
);

-- Enable RLS for the new table
ALTER TABLE clinic_inventory_reports ENABLE ROW LEVEL SECURITY;

-- 3. Update Policies to allow Assistant Access to ALL related tables
-- Drop existing policies to be safe (optional but cleaner)
DROP POLICY IF EXISTS "Assistant Access Inventory" ON clinic_inventory;
DROP POLICY IF EXISTS "Assistant Access Transactions" ON clinic_inventory_transactions;
DROP POLICY IF EXISTS "Assistant Access Reports" ON clinic_inventory_reports;

-- Re-create policies using the new claim
CREATE POLICY "Assistant Access Inventory" ON clinic_inventory FOR ALL USING (
    (auth.jwt() -> 'user_metadata' ->> 'assistant_target_id')::uuid = user_id
);

CREATE POLICY "Assistant Access Transactions" ON clinic_inventory_transactions FOR ALL USING (
    (auth.jwt() -> 'user_metadata' ->> 'assistant_target_id')::uuid = user_id
);

CREATE POLICY "Assistant Access Reports" ON clinic_inventory_reports FOR ALL USING (
    (auth.jwt() -> 'user_metadata' ->> 'assistant_target_id')::uuid = user_id
);
