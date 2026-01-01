-- جدول قصص الموزعين (Distributor Stories)
CREATE TABLE IF NOT EXISTS public.distributor_stories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    distributor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    caption TEXT,
    product_link_id TEXT, -- اختياري لربط منتج
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours'),
    views_count INTEGER DEFAULT 0
);

-- تفعيل الحماية (Row Level Security)
ALTER TABLE public.distributor_stories ENABLE ROW LEVEL SECURITY;

-- حذف السياسات القديمة إذا وجدت لتجنب الأخطاء عند إعادة التشغيل
DROP POLICY IF EXISTS "Stories are viewable by everyone" ON public.distributor_stories;
DROP POLICY IF EXISTS "Distributors can manage their own stories" ON public.distributor_stories;

-- سياسة: الجميع يمكنهم رؤية الستوريهات التي لم تنتهِ صلاحيتها
CREATE POLICY "Stories are viewable by everyone" 
ON public.distributor_stories FOR SELECT 
USING (expires_at > NOW());

-- سياسة: الموزع يمكنه إضافة وحذف الستوريهات الخاصة به فقط
CREATE POLICY "Distributors can manage their own stories" 
ON public.distributor_stories FOR ALL 
TO authenticated
USING (auth.uid() = distributor_id);

-- فهرس لسرعة جلب الستوريهات حسب الموزع والوقت
CREATE INDEX IF NOT EXISTS idx_stories_distributor ON distributor_stories(distributor_id);
CREATE INDEX IF NOT EXISTS idx_stories_expiry ON distributor_stories(expires_at);

-- دالة لزيادة عداد المشاهدات للستوري
CREATE OR REPLACE FUNCTION increment_story_view(p_story_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE distributor_stories
    SET views_count = views_count + 1
    WHERE id = p_story_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


ALTER TABLE distributor_stories ADD COLUMN IF NOT EXISTS likes_count INTEGER DEFAULT 0;

CREATE OR REPLACE FUNCTION increment_story_like(p_story_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE distributor_stories
    SET likes_count = likes_count + 1
    WHERE id = p_story_id;
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;

