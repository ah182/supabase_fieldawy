-- =====================================================
-- Activity Logs System
-- =====================================================
-- هذا الجدول يسجل كل النشاطات في التطبيق

CREATE TABLE IF NOT EXISTS public.activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_type TEXT NOT NULL, -- 'user_approved', 'user_rejected', 'product_added', 'offer_created', etc.
  user_id UUID REFERENCES public.users(uid) ON DELETE SET NULL,
  user_name TEXT, -- اسم المستخدم للعرض السريع
  user_role TEXT, -- دور المستخدم
  description TEXT NOT NULL, -- وصف النشاط
  metadata JSONB, -- بيانات إضافية (product_id, offer_id, etc.)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON public.activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_type ON public.activity_logs(activity_type);
CREATE INDEX IF NOT EXISTS idx_activity_logs_user ON public.activity_logs(user_id);

-- RLS Policies
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- Admin can read all activity logs
CREATE POLICY activity_logs_admin_select
ON public.activity_logs
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE uid = auth.uid()
    AND role = 'admin'
  )
);

-- Only system/admin can insert activity logs
CREATE POLICY activity_logs_admin_insert
ON public.activity_logs
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE uid = auth.uid()
    AND role = 'admin'
  )
);

-- =====================================================
-- Helper Function: Log Activity
-- =====================================================
CREATE OR REPLACE FUNCTION log_activity(
  p_activity_type TEXT,
  p_user_id UUID DEFAULT NULL,
  p_user_name TEXT DEFAULT NULL,
  p_user_role TEXT DEFAULT NULL,
  p_description TEXT DEFAULT '',
  p_metadata JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_log_id UUID;
BEGIN
  INSERT INTO public.activity_logs (
    activity_type,
    user_id,
    user_name,
    user_role,
    description,
    metadata
  ) VALUES (
    p_activity_type,
    p_user_id,
    p_user_name,
    p_user_role,
    p_description,
    p_metadata
  )
  RETURNING id INTO new_log_id;
  
  RETURN new_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- Triggers للتسجيل التلقائي
-- =====================================================

-- Trigger عند تغيير حالة المستخدم
CREATE OR REPLACE FUNCTION trigger_log_user_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.account_status != NEW.account_status THEN
    PERFORM log_activity(
      CASE 
        WHEN NEW.account_status = 'approved' THEN 'user_approved'
        WHEN NEW.account_status = 'rejected' THEN 'user_rejected'
        ELSE 'user_status_changed'
      END,
      NEW.uid,
      NEW.display_name,
      NEW.role,
      format('%s was %s', NEW.display_name, NEW.account_status),
      jsonb_build_object(
        'old_status', OLD.account_status,
        'new_status', NEW.account_status
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS log_user_status_change ON public.users;
CREATE TRIGGER log_user_status_change
AFTER UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION trigger_log_user_status_change();

-- Trigger عند إضافة منتج موزع جديد
CREATE OR REPLACE FUNCTION trigger_log_distributor_product_added()
RETURNS TRIGGER AS $$
DECLARE
  v_product_name TEXT;
  v_distributor_name TEXT;
BEGIN
  -- Get product name
  SELECT name INTO v_product_name
  FROM public.products
  WHERE id = NEW.product_id;
  
  -- Get distributor name
  SELECT display_name INTO v_distributor_name
  FROM public.users
  WHERE uid = NEW.distributor_id;
  
  PERFORM log_activity(
    'product_added',
    NEW.distributor_id,
    v_distributor_name,
    'distributor',
    format('%s added product: %s', v_distributor_name, v_product_name),
    jsonb_build_object(
      'product_id', NEW.product_id,
      'product_name', v_product_name,
      'package', NEW.package,
      'price', NEW.price
    )
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS log_distributor_product_added ON public.distributor_products;
CREATE TRIGGER log_distributor_product_added
AFTER INSERT ON public.distributor_products
FOR EACH ROW
EXECUTE FUNCTION trigger_log_distributor_product_added();

-- Trigger عند إضافة عرض جديد
CREATE OR REPLACE FUNCTION trigger_log_offer_created()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM log_activity(
    'offer_created',
    NEW.distributor_id,
    NEW.distributor_name,
    'distributor',
    format('New offer created: %s', NEW.title),
    jsonb_build_object(
      'offer_id', NEW.id,
      'title', NEW.title,
      'discount', NEW.discount,
      'expiration_date', NEW.expiration_date
    )
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS log_offer_created ON public.offers;
CREATE TRIGGER log_offer_created
AFTER INSERT ON public.offers
FOR EACH ROW
EXECUTE FUNCTION trigger_log_offer_created();

-- =====================================================
-- Sample Data (for testing)
-- =====================================================
-- يمكنك حذف هذا القسم بعد التجربة

-- INSERT INTO public.activity_logs (activity_type, description, metadata) VALUES
--   ('system_started', 'Admin Dashboard initialized', '{"version": "1.0.0"}'),
--   ('user_approved', 'Dr. Ahmed was approved', '{"user_id": "sample-id", "role": "doctor"}');

-- =====================================================
-- Cleanup Old Logs (Optional)
-- =====================================================
-- دالة لحذف السجلات القديمة (أقدم من 90 يوم)

CREATE OR REPLACE FUNCTION cleanup_old_activity_logs()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM public.activity_logs
  WHERE created_at < NOW() - INTERVAL '90 days';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- يمكن جدولة هذه الدالة لتشتغل تلقائياً كل أسبوع
