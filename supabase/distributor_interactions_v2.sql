-- Create table to track user interactions with distributors
CREATE TABLE IF NOT EXISTS public.distributor_interactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    distributor_id UUID NOT NULL, -- Links to the distributor (user id or specific distributor table)
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    interaction_type TEXT NOT NULL CHECK (interaction_type IN ('recommendation', 'report')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(distributor_id, user_id, interaction_type) -- Prevent duplicate same-type interactions
);

-- Enable RLS
ALTER TABLE public.distributor_interactions ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Users can view their own interactions" ON public.distributor_interactions;
DROP POLICY IF EXISTS "Users can insert their own interactions" ON public.distributor_interactions;
DROP POLICY IF EXISTS "Users can delete their own interactions" ON public.distributor_interactions;

CREATE POLICY "Users can view their own interactions" ON public.distributor_interactions 
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own interactions" ON public.distributor_interactions 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own interactions" ON public.distributor_interactions 
    FOR DELETE USING (auth.uid() = user_id);

-- Check interaction function
CREATE OR REPLACE FUNCTION check_distributor_interaction(
    p_distributor_id TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_dist_uuid UUID;
    v_recommendation BOOLEAN;
    v_report BOOLEAN;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('has_recommended', false, 'has_reported', false);
    END IF;

    -- Validate UUID
    BEGIN
        v_dist_uuid := p_distributor_id::UUID;
    EXCEPTION WHEN invalid_text_representation THEN
        -- Return false if ID is not a valid UUID (e.g. legacy int ID)
        RETURN jsonb_build_object('has_recommended', false, 'has_reported', false);
    END;

    SELECT EXISTS(SELECT 1 FROM distributor_interactions WHERE distributor_id = v_dist_uuid AND user_id = v_user_id AND interaction_type = 'recommendation')
    INTO v_recommendation;

    SELECT EXISTS(SELECT 1 FROM distributor_interactions WHERE distributor_id = v_dist_uuid AND user_id = v_user_id AND interaction_type = 'report')
    INTO v_report;

    RETURN jsonb_build_object('has_recommended', v_recommendation, 'has_reported', v_report);
END;
$$;


-- Updated Increment Recommendation
CREATE OR REPLACE FUNCTION toggle_distributor_recommendation(p_distributor_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_dist_uuid UUID;
    v_exists BOOLEAN;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    -- Validate UUID
    BEGIN
        v_dist_uuid := p_distributor_id::UUID;
    EXCEPTION WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Invalid distributor ID format';
    END;

    -- Check if already recommended
    SELECT EXISTS(SELECT 1 FROM distributor_interactions WHERE distributor_id = v_dist_uuid AND user_id = v_user_id AND interaction_type = 'recommendation')
    INTO v_exists;

    IF v_exists THEN
        -- Remove recommendation
        DELETE FROM distributor_interactions 
        WHERE distributor_id = v_dist_uuid AND user_id = v_user_id AND interaction_type = 'recommendation';
        
        -- Decrement count
        UPDATE public.users 
        SET recommendation_count = GREATEST(COALESCE(recommendation_count, 0) - 1, 0)
        WHERE id = v_dist_uuid; 

        RETURN jsonb_build_object('success', true, 'action', 'removed');
    ELSE
        -- Add recommendation
        INSERT INTO distributor_interactions (distributor_id, user_id, interaction_type)
        VALUES (v_dist_uuid, v_user_id, 'recommendation');
        
        -- Increment count
        UPDATE public.users 
        SET recommendation_count = COALESCE(recommendation_count, 0) + 1
        WHERE id = v_dist_uuid;

        -- If reported, remove report
        IF EXISTS(SELECT 1 FROM distributor_interactions WHERE distributor_id = v_dist_uuid AND user_id = v_user_id AND interaction_type = 'report') THEN
             DELETE FROM distributor_interactions 
             WHERE distributor_id = v_dist_uuid AND user_id = v_user_id AND interaction_type = 'report';
             
             UPDATE public.users 
             SET report_count = GREATEST(COALESCE(report_count, 0) - 1, 0)
             WHERE id = v_dist_uuid;
        END IF;

        RETURN jsonb_build_object('success', true, 'action', 'added');
    END IF;
END;
$$;

-- Updated Increment Report
CREATE OR REPLACE FUNCTION toggle_distributor_report(p_distributor_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_dist_uuid UUID;
    v_exists BOOLEAN;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    -- Validate UUID
    BEGIN
        v_dist_uuid := p_distributor_id::UUID;
    EXCEPTION WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Invalid distributor ID format';
    END;

    -- Check if already reported
    SELECT EXISTS(SELECT 1 FROM distributor_interactions WHERE distributor_id = v_dist_uuid AND user_id = v_user_id AND interaction_type = 'report')
    INTO v_exists;

    IF v_exists THEN
        -- Remove report
        DELETE FROM distributor_interactions 
        WHERE distributor_id = v_dist_uuid AND user_id = v_user_id AND interaction_type = 'report';
        
        -- Decrement count
        UPDATE public.users 
        SET report_count = GREATEST(COALESCE(report_count, 0) - 1, 0)
        WHERE id = v_dist_uuid;

        RETURN jsonb_build_object('success', true, 'action', 'removed');
    ELSE
        -- Add report
        INSERT INTO distributor_interactions (distributor_id, user_id, interaction_type)
        VALUES (v_dist_uuid, v_user_id, 'report');
        
        -- Increment count
        UPDATE public.users 
        SET report_count = COALESCE(report_count, 0) + 1
        WHERE id = v_dist_uuid;

        -- If recommended, remove recommendation
        IF EXISTS(SELECT 1 FROM distributor_interactions WHERE distributor_id = v_dist_uuid AND user_id = v_user_id AND interaction_type = 'recommendation') THEN
             DELETE FROM distributor_interactions 
             WHERE distributor_id = v_dist_uuid AND user_id = v_user_id AND interaction_type = 'recommendation';
             
             UPDATE public.users 
             SET recommendation_count = GREATEST(COALESCE(recommendation_count, 0) - 1, 0)
             WHERE id = v_dist_uuid;
        END IF;

        RETURN jsonb_build_object('success', true, 'action', 'added');
    END IF;
END;
$$;
