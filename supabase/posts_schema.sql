-- ============================================
-- Social Posts System Schema
-- نظام البوستات للدكاترة فقط
-- ============================================

-- 1. Posts Table (جدول البوستات)
CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (char_length(content) <= 500),
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);

-- 2. Post Likes Table (جدول الإعجابات)
CREATE TABLE IF NOT EXISTS post_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(post_id, user_id) -- منع الإعجاب المتكرر
);

CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON post_likes(user_id);

-- 3. Post Comments Table with Nested Replies (جدول التعليقات مع الردود)
CREATE TABLE IF NOT EXISTS post_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES post_comments(id) ON DELETE CASCADE, -- للردود المتداخلة
    content TEXT NOT NULL CHECK (char_length(content) <= 300),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON post_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_parent_id ON post_comments(parent_id);

-- 4. Post Reports Table (جدول البلاغات)
CREATE TABLE IF NOT EXISTS post_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(post_id, reporter_id) -- منع البلاغ المتكرر
);

-- ============================================
-- Row Level Security (RLS) Policies
-- ============================================

-- Enable RLS on all tables
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_reports ENABLE ROW LEVEL SECURITY;

-- Helper function to check if user is doctor or admin
CREATE OR REPLACE FUNCTION is_doctor_or_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND role IN ('doctor', 'admin')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Posts Policies
CREATE POLICY "Doctors and admins can view posts" ON posts
    FOR SELECT USING (is_doctor_or_admin());

CREATE POLICY "Doctors can create posts" ON posts
    FOR INSERT WITH CHECK (
        auth.uid() = user_id AND is_doctor_or_admin()
    );

CREATE POLICY "Users can update own posts" ON posts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own posts or admin can delete any" ON posts
    FOR DELETE USING (
        auth.uid() = user_id OR is_admin()
    );

-- Likes Policies
CREATE POLICY "Doctors and admins can view likes" ON post_likes
    FOR SELECT USING (is_doctor_or_admin());

CREATE POLICY "Doctors can like posts" ON post_likes
    FOR INSERT WITH CHECK (
        auth.uid() = user_id AND is_doctor_or_admin()
    );

CREATE POLICY "Users can remove own likes" ON post_likes
    FOR DELETE USING (auth.uid() = user_id);

-- Comments Policies
CREATE POLICY "Doctors and admins can view comments" ON post_comments
    FOR SELECT USING (is_doctor_or_admin());

CREATE POLICY "Doctors can add comments" ON post_comments
    FOR INSERT WITH CHECK (
        auth.uid() = user_id AND is_doctor_or_admin()
    );

CREATE POLICY "Users can delete own comments or admin can delete any" ON post_comments
    FOR DELETE USING (
        auth.uid() = user_id OR is_admin()
    );

-- Reports Policies
CREATE POLICY "Users can create reports" ON post_reports
    FOR INSERT WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Only admins can view reports" ON post_reports
    FOR SELECT USING (is_admin());

-- ============================================
-- Views for easier querying
-- ============================================

-- View to get posts with counts and user info
CREATE OR REPLACE VIEW posts_with_details AS
SELECT 
    p.*,
    u.display_name as user_name,
    u.photo_url as user_photo,
    u.role as user_role,
    COALESCE(likes.count, 0) as likes_count,
    COALESCE(comments.count, 0) as comments_count
FROM posts p
LEFT JOIN users u ON p.user_id = u.id
LEFT JOIN (
    SELECT post_id, COUNT(*) as count 
    FROM post_likes 
    GROUP BY post_id
) likes ON p.id = likes.post_id
LEFT JOIN (
    SELECT post_id, COUNT(*) as count 
    FROM post_comments 
    GROUP BY post_id
) comments ON p.id = comments.post_id
ORDER BY p.created_at DESC;

-- View to get comments with user info
CREATE OR REPLACE VIEW comments_with_details AS
SELECT 
    c.*,
    u.display_name as user_name,
    u.photo_url as user_photo,
    u.role as user_role
FROM post_comments c
LEFT JOIN users u ON c.user_id = u.id
ORDER BY c.created_at ASC;
