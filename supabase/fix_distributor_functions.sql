-- Drop potentially ambiguous function signatures (UUID vs TEXT)
DROP FUNCTION IF EXISTS check_distributor_interaction(uuid);
DROP FUNCTION IF EXISTS toggle_distributor_recommendation(uuid);
DROP FUNCTION IF EXISTS toggle_distributor_report(uuid);

-- Drop TEXT signatures to ensure clean recreation
DROP FUNCTION IF EXISTS check_distributor_interaction(text);
DROP FUNCTION IF EXISTS toggle_distributor_recommendation(text);
DROP FUNCTION IF EXISTS toggle_distributor_report(text);

-- Recreate Check Interaction (TEXT input)
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
        -- Return false if ID is not a valid UUID
        RETURN jsonb_build_object('has_recommended', false, 'has_reported', false);
    END;

    SELECT EXISTS(SELECT 1 FROM distributor_interactions WHERE distributor_id = v_dist_uuid AND user_id = v_user_id AND interaction_type = 'recommendation')
    INTO v_recommendation;

    SELECT EXISTS(SELECT 1 FROM distributor_interactions WHERE distributor_id = v_dist_uuid AND user_id = v_user_id AND interaction_type = 'report')
    INTO v_report;

    RETURN jsonb_build_object('has_recommended', v_recommendation, 'has_reported', v_report);
END;
$$;

-- Recreate Toggle Recommendation (TEXT input)
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

-- Recreate Toggle Report (TEXT input)
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
