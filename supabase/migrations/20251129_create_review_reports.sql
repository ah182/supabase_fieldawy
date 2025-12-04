-- 1. Create table for review reports
CREATE TABLE IF NOT EXISTS public.review_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES public.product_reviews(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL, -- e.g., 'spam', 'harassment', 'inappropriate'
    description TEXT,
    status TEXT DEFAULT 'pending', -- 'pending', 'reviewed', 'resolved', 'dismissed'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. RLS Policies for review_reports
ALTER TABLE public.review_reports ENABLE ROW LEVEL SECURITY;

-- Users can create reports
CREATE POLICY "Users can create reports" 
ON public.review_reports FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = reporter_id);

-- Users can view their own reports
CREATE POLICY "Users can view own reports" 
ON public.review_reports FOR SELECT 
TO authenticated 
USING (auth.uid() = reporter_id);

-- Admins can view all reports (assuming admin check via function or separate policy)
-- For now, we'll stick to basic user permissions.

-- 3. Function to report a review
CREATE OR REPLACE FUNCTION public.report_review(
    p_review_id UUID,
    p_reason TEXT,
    p_description TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_reporter_id UUID;
    v_existing_report UUID;
BEGIN
    v_reporter_id := auth.uid();
    
    IF v_reporter_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    -- Check if user already reported this review
    SELECT id INTO v_existing_report
    FROM public.review_reports
    WHERE review_id = p_review_id AND reporter_id = v_reporter_id;

    IF v_existing_report IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'You have already reported this review');
    END IF;

    -- Insert report
    INSERT INTO public.review_reports (review_id, reporter_id, reason, description)
    VALUES (p_review_id, v_reporter_id, p_reason, p_description);

    RETURN jsonb_build_object('success', true, 'message', 'Report submitted successfully');
END;
$$;

GRANT EXECUTE ON FUNCTION public.report_review(UUID, TEXT, TEXT) TO authenticated;
