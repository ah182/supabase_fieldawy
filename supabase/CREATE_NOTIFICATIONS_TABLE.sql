-- =====================================================
-- NOTIFICATIONS SENT TABLE
-- =====================================================
-- Track all sent push notifications

CREATE TABLE IF NOT EXISTS public.notifications_sent (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Notification content
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  
  -- Target
  target_type TEXT NOT NULL, -- 'all', 'role', 'governorate'
  target_value TEXT, -- role name or governorate name
  
  -- Stats
  recipients_count INTEGER DEFAULT 0,
  
  -- Metadata
  sent_by TEXT, -- admin email
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Additional data
  metadata JSONB
);

-- Indexes
CREATE INDEX idx_notifications_sent_at ON public.notifications_sent(sent_at DESC);
CREATE INDEX idx_notifications_target ON public.notifications_sent(target_type, target_value);

-- RLS
ALTER TABLE public.notifications_sent ENABLE ROW LEVEL SECURITY;

-- Allow admins to insert
CREATE POLICY notifications_sent_insert
ON public.notifications_sent
FOR INSERT
WITH CHECK (true);

-- Allow admins to select
CREATE POLICY notifications_sent_select
ON public.notifications_sent
FOR SELECT
USING (true);

-- =====================================================
-- View: Recent Notifications (Last 100)
-- =====================================================

CREATE OR REPLACE VIEW recent_notifications AS
SELECT 
  id,
  title,
  message,
  target_type,
  target_value,
  recipients_count,
  sent_at
FROM public.notifications_sent
ORDER BY sent_at DESC
LIMIT 100;

-- =====================================================
-- Success Message
-- =====================================================

SELECT 
  'Notifications table created successfully!' AS status,
  (SELECT COUNT(*) FROM public.notifications_sent) AS notifications_count;
