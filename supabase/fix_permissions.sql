-- Grant permissions to ensure the table is accessible
GRANT ALL ON TABLE public.distributor_interactions TO postgres;
GRANT ALL ON TABLE public.distributor_interactions TO service_role;
GRANT ALL ON TABLE public.distributor_interactions TO authenticated;

-- Ensure sequences if any (UUID primary key doesn't use sequence usually but good practice)
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Force RLS to be applied correctly
ALTER TABLE public.distributor_interactions FORCE ROW LEVEL SECURITY;

-- Verify policy again (re-run just in case)
DROP POLICY IF EXISTS "Users can view their own interactions" ON public.distributor_interactions;
CREATE POLICY "Users can view their own interactions" ON public.distributor_interactions 
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own interactions" ON public.distributor_interactions;
CREATE POLICY "Users can insert their own interactions" ON public.distributor_interactions 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own interactions" ON public.distributor_interactions;
CREATE POLICY "Users can delete their own interactions" ON public.distributor_interactions 
    FOR DELETE USING (auth.uid() = user_id);
