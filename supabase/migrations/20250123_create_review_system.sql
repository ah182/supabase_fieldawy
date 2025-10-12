-- ============================================================================
-- Migration: Review Requests System
-- Date: 2025-01-23
-- Description: نظام طلبات التقييم والمراجعات للمنتجات
-- ============================================================================

-- ============================================================================
-- 0. CHECK PREREQUISITES
-- ============================================================================

-- التحقق من وجود جدول users
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'users') THEN
    RAISE EXCEPTION 'جدول users غير موجود! يجب تشغيل schema.sql أولاً';
  END IF;
  
  -- التحقق من وجود عمود uid
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'uid'
  ) THEN
    RAISE EXCEPTION 'عمود uid غير موجود في جدول users!';
  END IF;
END $$;

-- ============================================================================
-- 1. ENUMS
-- ============================================================================

-- نوع المنتج (عادي أو OCR)
DO $$ BEGIN
  CREATE TYPE product_type_enum AS ENUM ('product', 'ocr_product');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- حالة طلب التقييم
DO $$ BEGIN
  CREATE TYPE review_request_status AS ENUM ('active', 'closed', 'archived');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- ============================================================================
-- 2. TABLE: review_requests
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.review_requests (
  -- المعرفات الأساسية
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- معلومات المنتج (يدعم products و ocr_products)
  product_id uuid NOT NULL,
  product_type product_type_enum NOT NULL DEFAULT 'product',
  product_name text, -- كاش للاسم لسرعة العرض
  
  -- معلومات الطالب
  requested_by uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  requester_name text, -- كاش للاسم
  
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
  
  -- قيود فريدة: منتج واحد = طلب واحد (للنوعين)
  CONSTRAINT unique_product_request UNIQUE (product_id, product_type)
);

-- الفهارس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_review_requests_requested_by ON public.review_requests(requested_by);
CREATE INDEX IF NOT EXISTS idx_review_requests_requested_at ON public.review_requests(requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_review_requests_status ON public.review_requests(status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_review_requests_product ON public.review_requests(product_id, product_type);
CREATE INDEX IF NOT EXISTS idx_review_requests_avg_rating ON public.review_requests(avg_rating DESC) WHERE avg_rating IS NOT NULL;

-- تعليق توضيحي
COMMENT ON TABLE public.review_requests IS 'طلبات تقييم المنتجات - كل منتج يمكن طلب تقييمه مرة واحدة فقط';
COMMENT ON COLUMN public.review_requests.comments_count IS 'عدد التعليقات النصية (حد أقصى 5)';
COMMENT ON COLUMN public.review_requests.total_reviews_count IS 'إجمالي عدد التقييمات (بدون حد)';

-- ============================================================================
-- 3. TABLE: product_reviews
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.product_reviews (
  -- المعرفات الأساسية
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- الربط مع طلب التقييم
  review_request_id uuid NOT NULL REFERENCES public.review_requests(id) ON DELETE CASCADE,
  
  -- معلومات المنتج (للبحث السريع)
  product_id uuid NOT NULL,
  product_type product_type_enum NOT NULL DEFAULT 'product',
  
  -- معلومات المستخدم
  user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  user_name text, -- كاش للاسم
  
  -- التقييم
  rating smallint NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  has_comment boolean GENERATED ALWAYS AS (comment IS NOT NULL AND length(comment) > 0) STORED,
  
  -- معلومات إضافية
  is_verified_purchase boolean DEFAULT false, -- هل المستخدم اشترى المنتج فعلاً
  helpful_count int DEFAULT 0 CHECK (helpful_count >= 0), -- عدد من وجدوا التقييم مفيد
  
  -- التواريخ
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  
  -- معلومات إضافية
  metadata jsonb DEFAULT '{}'::jsonb,
  
  -- قيد فريد: مستخدم واحد = تقييم واحد لكل طلب
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
COMMENT ON COLUMN public.product_reviews.has_comment IS 'يتم حسابها تلقائياً - هل يوجد تعليق نصي';

-- ============================================================================
-- 4. TABLE: review_helpful_votes
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.review_helpful_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES public.product_reviews(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  is_helpful boolean NOT NULL, -- true = مفيد, false = غير مفيد
  created_at timestamptz DEFAULT now() NOT NULL,
  
  -- قيد فريد: مستخدم واحد = صوت واحد لكل تقييم
  CONSTRAINT one_vote_per_user_per_review UNIQUE (review_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_review_helpful_votes_review ON public.review_helpful_votes(review_id);
CREATE INDEX IF NOT EXISTS idx_review_helpful_votes_user ON public.review_helpful_votes(user_id);

COMMENT ON TABLE public.review_helpful_votes IS 'أصوات المستخدمين على فائدة التقييمات';



-- ============================================================================
-- 6. TRIGGERS: Auto-update updated_at
-- ============================================================================

-- دالة تحديث updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger لـ review_requests
DROP TRIGGER IF EXISTS trg_review_requests_updated_at ON public.review_requests;
CREATE TRIGGER trg_review_requests_updated_at
  BEFORE UPDATE ON public.review_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- Trigger لـ product_reviews
DROP TRIGGER IF EXISTS trg_product_reviews_updated_at ON public.product_reviews;
CREATE TRIGGER trg_product_reviews_updated_at
  BEFORE UPDATE ON public.product_reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- 7. FUNCTION: حساب متوسط التقييم وتحديث الإحصائيات
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_review_request_stats(p_request_id uuid)
RETURNS void AS $$
DECLARE
  v_total_reviews int;
  v_total_rating_sum int;
  v_avg_rating numeric(3,2);
  v_comments_count int;
BEGIN
  -- حساب الإحصائيات من product_reviews
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
  
  -- تحديث review_requests
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

COMMENT ON FUNCTION public.update_review_request_stats IS 'تحديث إحصائيات طلب التقييم (العدد، المتوسط، الحالة)';

-- ============================================================================
-- 8. TRIGGER: تحديث الإحصائيات تلقائياً عند إضافة/تعديل/حذف تقييم
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trigger_update_review_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- في حالة INSERT أو UPDATE
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    PERFORM public.update_review_request_stats(NEW.review_request_id);
  END IF;
  
  -- في حالة DELETE
  IF TG_OP = 'DELETE' THEN
    PERFORM public.update_review_request_stats(OLD.review_request_id);
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger على product_reviews
DROP TRIGGER IF EXISTS trg_update_review_stats ON public.product_reviews;
CREATE TRIGGER trg_update_review_stats
  AFTER INSERT OR UPDATE OR DELETE ON public.product_reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_update_review_stats();

-- ============================================================================
-- 9. TRIGGER: تحديث helpful_count في product_reviews
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trigger_update_helpful_count()
RETURNS TRIGGER AS $$
BEGIN
  -- تحديث عدد الأصوات المفيدة
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
-- نهاية الـ Migration
-- ============================================================================

-- عرض رسالة نجاح
DO $$
BEGIN
  RAISE NOTICE '✅ Review System Migration completed successfully!';
  RAISE NOTICE '📊 Tables created: review_requests, product_reviews, review_helpful_votes';
  RAISE NOTICE '⚡ Triggers configured for auto-updates';
  RAISE NOTICE '🔒 RLS enabled on all tables';
END $$;
