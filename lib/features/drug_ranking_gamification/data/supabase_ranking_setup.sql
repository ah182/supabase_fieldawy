-- 1. Create the table to store ranking votes
CREATE TABLE IF NOT EXISTS public.drug_ranking_votes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) NOT NULL,
    product_id text NOT NULL,
    rank_position int NOT NULL CHECK (rank_position BETWEEN 1 AND 4),
    active_principle text,
    package_type text,
    created_at timestamptz DEFAULT now()
);

-- 2. Enable Row Level Security (RLS)
ALTER TABLE public.drug_ranking_votes ENABLE ROW LEVEL SECURITY;

-- 3. Create RLS Policies
-- Allow users to insert their own votes
CREATE POLICY "Users can insert their own votes" 
ON public.drug_ranking_votes FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

-- Allow users to read votes (needed for transparency or debugging, optional)
CREATE POLICY "Users can view all votes" 
ON public.drug_ranking_votes FOR SELECT 
TO authenticated 
USING (true);

-- 4. Create the function to calculate efficiency scores
-- Formula: Rank 1 = 4 pts, Rank 2 = 3 pts, Rank 3 = 2 pts, Rank 4 = 1 pt.
CREATE OR REPLACE FUNCTION get_drug_efficiency_scores()
RETURNS TABLE (
    product_id text,
    efficiency_score bigint,
    vote_count bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.product_id,
        SUM(5 - v.rank_position) as efficiency_score,
        COUNT(*) as vote_count
    FROM 
        public.drug_ranking_votes v
    GROUP BY 
        v.product_id;
END;
$$ LANGUAGE plpgsql;
