-- ============================================================================
-- Migration: Review Requests System (Simplified Version)
-- Date: 2025-01-23
-- Description: نسخة مبسطة بدون foreign keys لـ users (للتجربة)
-- ============================================================================

-- ============================================================================
-- 1. ENUMS
-- ============================================================================

DO $$ BEGIN
  CREATE TYPE product_type_enum AS ENUM ('product', 'ocr_product');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE review_request_status AS ENUM ('active', 'closed', 'archived');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- ============================================================================
-- 2. TABLE: review_requests
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.review_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- معلومات المنتج
  product_id uuid NOT NULL,
  product_type product_type_enum NOT NULL DEFAULT 'product',
  product_name text,
  
  -- معلومات الطالب (بدون foreign key)
  requested_by uuid NOT NULL,
  requester_name text,
  
  -- الحالة والعدادات
  status review_request_status DEFAULT 'active',
  comments_count int DEFAULT 0 CHECK (comments_count >= 0 AND comments_count <= 5),
  total_reviews_count int DEFAULT 0 CHECK (total_reviews_count >= 0),
  
  -- التقييم المجمع
  avg_rating numeric(3,2) CHECK (avg_rating >= 1.00 AND avg_rating <= 5.00),
  total_rating_sum int DEFAULT 0,
  
  -- التواريخ
  requested_at timestamptz DEFAULT now() NOT NULL,
  closed_at timestamptz,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  
  -- معلومات إضافية
  closed_reason text,
  metadata jsonb DEFAULT '{}'::jsonb,
  
  -- قيود فريدة
  CONSTRAINT unique_product_request UNIQUE (product_id, product_type)
);

-- الفهارس
CREATE INDEX IF NOT EXISTS idx_review_requests_requested_by ON public.review_requests(requested_by);
CREATE INDEX IF NOT EXISTS idx_review_requests_requested_at ON public.review_requests(requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_review_requests_status ON public.review_requests(status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_review_requests_product ON public.review_requests(product_id, product_type);
CREATE INDEX IF NOT EXISTS idx_review_requests_avg_rating ON public.review_requests(avg_rating DESC) WHERE avg_rating IS NOT NULL;

COMMENT ON TABLE public.review_requests IS 'طلبات تقييم المنتجات';

-- ============================================================================
-- 3. TABLE: product_reviews
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.product_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- الربط مع طلب التقييم
  review_request_id uuid NOT NULL REFERENCES public.review_requests(id) ON DELETE CASCADE,
  
  -- معلومات المنتج
  product_id uuid NOT NULL,
  product_type product_type_enum NOT NULL DEFAULT 'product',
  
  -- معلومات المستخدم (بدون foreign key)
  user_id uuid NOT NULL,
  user_name text,
  
  -- التقييم
  rating smallint NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  has_comment boolean GENERATED ALWAYS AS (comment IS NOT NULL AND length(comment) > 0) STORED,
  
  -- معلومات إضافية
  is_verified_purchase boolean DEFAULT false,
  helpful_count int DEFAULT 0 CHECK (helpful_count >= 0),
  
  -- التواريخ
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  
  metadata jsonb DEFAULT '{}'::jsonb,
  
  -- قيد فريد
  CONSTRAINT one_review_per_user_per_request UNIQUE (review_request_id, user_id)
);

-- الفهارس
CREATE INDEX IF NOT EXISTS idx_product_reviews_request_id ON public.product_reviews(review_request_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_product ON public.product_reviews(product_id, product_type);
CREATE INDEX IF NOT EXISTS idx_product_reviews_user_id ON public.product_reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_rating ON public.product_reviews(rating DESC);
CREATE INDEX IF NOT EXISTS idx_product_reviews_created_at ON public.product_reviews(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_reviews_has_comment ON public.product_reviews(has_comment) WHERE has_comment = true;

COMMENT ON TABLE public.product_reviews IS 'التقييمات والمراجعات للمنتجات';

-- ============================================================================
-- 4. TABLE: review_helpful_votes
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.review_helpful_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES public.product_reviews(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  is_helpful boolean NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  
  CONSTRAINT one_vote_per_user_per_review UNIQUE (review_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_review_helpful_votes_review ON public.review_helpful_votes(review_id);
CREATE INDEX IF NOT EXISTS idx_review_helpful_votes_user ON public.review_helpful_votes(user_id);



-- ============================================================================
-- 6. TRIGGERS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_review_requests_updated_at ON public.review_requests;
CREATE TRIGGER trg_review_requests_updated_at
  BEFORE UPDATE ON public.review_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_product_reviews_updated_at ON public.product_reviews;
CREATE TRIGGER trg_product_reviews_updated_at
  BEFORE UPDATE ON public.product_reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- 7. UPDATE STATS FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_review_request_stats(p_request_id uuid)
RETURNS void AS $$
DECLARE
  v_total_reviews int;
  v_total_rating_sum int;
  v_avg_rating numeric(3,2);
  v_comments_count int;
BEGIN
  SELECT 
    COUNT(*),
    COALESCE(SUM(rating), 0),
    CASE WHEN COUNT(*) > 0 THEN ROUND(AVG(rating)::numeric, 2) ELSE NULL END,
    COUNT(*) FILTER (WHERE has_comment = true)
  INTO 
    v_total_reviews,
    v_total_rating_sum,
    v_avg_rating,
    v_comments_count
  FROM public.product_reviews
  WHERE review_request_id = p_request_id;
  
  UPDATE public.review_requests
  SET 
    total_reviews_count = v_total_reviews,
    total_rating_sum = v_total_rating_sum,
    avg_rating = v_avg_rating,
    comments_count = v_comments_count,
    status = CASE 
      WHEN v_comments_count >= 5 THEN 'closed'::review_request_status
      ELSE 'active'::review_request_status
    END,
    closed_at = CASE 
      WHEN v_comments_count >= 5 AND closed_at IS NULL THEN now()
      ELSE closed_at
    END,
    closed_reason = CASE 
      WHEN v_comments_count >= 5 AND closed_reason IS NULL THEN 'تم الوصول للحد الأقصى من التعليقات (5)'
      ELSE closed_reason
    END
  WHERE id = p_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 8. AUTO UPDATE STATS TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trigger_update_review_stats()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    PERFORM public.update_review_request_stats(NEW.review_request_id);
  END IF;
  
  IF TG_OP = 'DELETE' THEN
    PERFORM public.update_review_request_stats(OLD.review_request_id);
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_review_stats ON public.product_reviews;
CREATE TRIGGER trg_update_review_stats
  AFTER INSERT OR UPDATE OR DELETE ON public.product_reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_update_review_stats();

-- ============================================================================
-- 9. UPDATE HELPFUL COUNT TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trigger_update_helpful_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.product_reviews
  SET helpful_count = (
    SELECT COUNT(*) 
    FROM public.review_helpful_votes 
    WHERE review_id = COALESCE(NEW.review_id, OLD.review_id)
      AND is_helpful = true
  )
  WHERE id = COALESCE(NEW.review_id, OLD.review_id);
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_helpful_count ON public.review_helpful_votes;
CREATE TRIGGER trg_update_helpful_count
  AFTER INSERT OR UPDATE OR DELETE ON public.review_helpful_votes
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_update_helpful_count();

-- ============================================================================
-- 10. ENABLE RLS
-- ============================================================================

ALTER TABLE public.review_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_helpful_votes ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- نهاية
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Review System created successfully (Simple Version)!';
  RAISE NOTICE '📊 Tables: review_requests, product_reviews, review_helpful_votes';
  RAISE NOTICE '⚡ Triggers configured';
  RAISE NOTICE '🔒 RLS enabled';
  RAISE NOTICE '⚠️  Note: No foreign keys to users table (for compatibility)';
END $$;
