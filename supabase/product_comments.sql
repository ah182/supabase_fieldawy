-- Create table for product comments
CREATE TABLE IF NOT EXISTS product_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id TEXT NOT NULL,
    distributor_id TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    content TEXT NOT NULL CHECK (char_length(content) > 0),
    likes_count INTEGER DEFAULT 0,
    dislikes_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create table for comment interactions (likes/dislikes)
CREATE TABLE IF NOT EXISTS product_comment_interactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    comment_id UUID REFERENCES product_comments(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    interaction_type TEXT NOT NULL CHECK (interaction_type IN ('like', 'dislike')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(comment_id, user_id)
);

-- Enable RLS
ALTER TABLE product_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_comment_interactions ENABLE ROW LEVEL SECURITY;

-- Policies

-- Drop existing policies to ensure idempotency
DROP POLICY IF EXISTS "Public comments are viewable by everyone" ON product_comments;
DROP POLICY IF EXISTS "Users can insert their own comments" ON product_comments;
DROP POLICY IF EXISTS "Users can delete their own comments" ON product_comments;
DROP POLICY IF EXISTS "Users can update their own comments" ON product_comments;

DROP POLICY IF EXISTS "Interactions are viewable by everyone" ON product_comment_interactions;
DROP POLICY IF EXISTS "Users can insert their own interactions" ON product_comment_interactions;
DROP POLICY IF EXISTS "Users can update their own interactions" ON product_comment_interactions;
DROP POLICY IF EXISTS "Users can delete their own interactions" ON product_comment_interactions;

CREATE POLICY "Public comments are viewable by everyone" ON product_comments FOR SELECT USING (true);
CREATE POLICY "Users can insert their own comments" ON product_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own comments" ON product_comments FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "Users can update their own comments" ON product_comments FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Interactions are viewable by everyone" ON product_comment_interactions FOR SELECT USING (true);
CREATE POLICY "Users can insert their own interactions" ON product_comment_interactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own interactions" ON product_comment_interactions FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own interactions" ON product_comment_interactions FOR DELETE USING (auth.uid() = user_id);

-- Function to add a comment with limit check (Max 5 comments per user per product)
CREATE OR REPLACE FUNCTION add_product_comment(
    p_product_id TEXT,
    p_distributor_id TEXT,
    p_content TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_count INTEGER;
    v_new_comment JSONB;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Check limit
    SELECT COUNT(*) INTO v_count
    FROM product_comments
    WHERE product_id = p_product_id
      AND distributor_id = p_distributor_id
      AND user_id = v_user_id;

    IF v_count >= 5 THEN
        RAISE EXCEPTION 'Limit exceeded: You can only add 5 comments per product.';
    END IF;

    -- Insert
    INSERT INTO product_comments (product_id, distributor_id, user_id, content)
    VALUES (p_product_id, p_distributor_id, v_user_id, p_content)
    RETURNING to_jsonb(product_comments.*) INTO v_new_comment;

    RETURN v_new_comment;
END;
$$;

-- Function to toggle comment interaction
CREATE OR REPLACE FUNCTION toggle_product_comment_interaction(
    p_comment_id UUID,
    p_interaction_type TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_existing_type TEXT;
    v_likes_delta INTEGER := 0;
    v_dislikes_delta INTEGER := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Check existing interaction
    SELECT interaction_type INTO v_existing_type
    FROM product_comment_interactions
    WHERE comment_id = p_comment_id AND user_id = v_user_id;

    IF v_existing_type IS NOT NULL THEN
        IF v_existing_type = p_interaction_type THEN
            -- Toggle OFF
            DELETE FROM product_comment_interactions
            WHERE comment_id = p_comment_id AND user_id = v_user_id;

            IF p_interaction_type = 'like' THEN v_likes_delta := -1; END IF;
            IF p_interaction_type = 'dislike' THEN v_dislikes_delta := -1; END IF;
        ELSE
            -- Switch type
            UPDATE product_comment_interactions
            SET interaction_type = p_interaction_type
            WHERE comment_id = p_comment_id AND user_id = v_user_id;

            IF v_existing_type = 'like' THEN v_likes_delta := -1; END IF;
            IF v_existing_type = 'dislike' THEN v_dislikes_delta := -1; END IF;
            IF p_interaction_type = 'like' THEN v_likes_delta := v_likes_delta + 1; END IF;
            IF p_interaction_type = 'dislike' THEN v_dislikes_delta := v_dislikes_delta + 1; END IF;
        END IF;
    ELSE
        -- New interaction
        INSERT INTO product_comment_interactions (comment_id, user_id, interaction_type)
        VALUES (p_comment_id, v_user_id, p_interaction_type);

        IF p_interaction_type = 'like' THEN v_likes_delta := 1; END IF;
        IF p_interaction_type = 'dislike' THEN v_dislikes_delta := 1; END IF;
    END IF;

    -- Update counts
    UPDATE product_comments
    SET 
        likes_count = likes_count + v_likes_delta,
        dislikes_count = dislikes_count + v_dislikes_delta
    WHERE id = p_comment_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- Function to get comments with user info and current user interaction
CREATE OR REPLACE FUNCTION get_product_comments(
    p_product_id TEXT,
    p_distributor_id TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_result JSONB;
BEGIN
    v_user_id := auth.uid();

    SELECT jsonb_agg(
        jsonb_build_object(
            'id', c.id,
            'product_id', c.product_id,
            'distributor_id', c.distributor_id,
            'user_id', c.user_id,
            'content', c.content,
            'likes_count', c.likes_count,
            'dislikes_count', c.dislikes_count,
            'created_at', c.created_at,
            'user_name', u.display_name,
            'user_photo', u.photo_url,
            'user_role', u.role,
            'is_mine', (c.user_id = v_user_id),
            'my_interaction', (
                SELECT interaction_type 
                FROM product_comment_interactions i 
                WHERE i.comment_id = c.id AND i.user_id = v_user_id
            )
        ) ORDER BY c.created_at DESC
    ) INTO v_result
    FROM product_comments c
    JOIN public.users u ON c.user_id = u.id
    WHERE c.product_id = p_product_id AND c.distributor_id = p_distributor_id;

    RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;
