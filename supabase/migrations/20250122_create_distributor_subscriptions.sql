-- Create distributor_subscriptions table
-- Users can subscribe to specific distributors to receive all their notifications

CREATE TABLE IF NOT EXISTS distributor_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    distributor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, distributor_id)
);

-- Create index for faster lookups
CREATE INDEX idx_distributor_subscriptions_user_id ON distributor_subscriptions(user_id);
CREATE INDEX idx_distributor_subscriptions_distributor_id ON distributor_subscriptions(distributor_id);
CREATE INDEX idx_distributor_subscriptions_user_distributor ON distributor_subscriptions(user_id, distributor_id);

-- Enable RLS
ALTER TABLE distributor_subscriptions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own subscriptions
CREATE POLICY "Users can view own distributor subscriptions"
ON distributor_subscriptions
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can insert their own subscriptions
CREATE POLICY "Users can insert own distributor subscriptions"
ON distributor_subscriptions
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own subscriptions
CREATE POLICY "Users can delete own distributor subscriptions"
ON distributor_subscriptions
FOR DELETE
USING (auth.uid() = user_id);

-- Helper function to check if user is subscribed to a distributor
CREATE OR REPLACE FUNCTION is_subscribed_to_distributor(p_user_id UUID, p_distributor_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM distributor_subscriptions 
        WHERE user_id = p_user_id 
        AND distributor_id = p_distributor_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to get user's subscribed distributors
CREATE OR REPLACE FUNCTION get_subscribed_distributors(p_user_id UUID)
RETURNS TABLE(distributor_id UUID, distributor_name TEXT, created_at TIMESTAMP WITH TIME ZONE) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ds.distributor_id,
        COALESCE(u.full_name, u.username, 'موزع') as distributor_name,
        ds.created_at
    FROM distributor_subscriptions ds
    JOIN users u ON u.id = ds.distributor_id
    WHERE ds.user_id = p_user_id
    ORDER BY ds.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comments for documentation
COMMENT ON TABLE distributor_subscriptions IS 'Stores user subscriptions to specific distributors for priority notifications';
COMMENT ON COLUMN distributor_subscriptions.user_id IS 'The user who subscribed';
COMMENT ON COLUMN distributor_subscriptions.distributor_id IS 'The distributor being subscribed to';
