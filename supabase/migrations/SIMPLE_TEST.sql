-- اختبار بسيط جداً لمعرفة مصدر الخطأ

-- 1. إنشاء جدول product_views فقط
CREATE TABLE IF NOT EXISTS public.product_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id TEXT NOT NULL,
  user_id UUID,
  user_role TEXT,
  product_type TEXT,
  viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. اختبار إدراج بيانات
INSERT INTO public.product_views (product_id, product_type)
VALUES ('test-001', 'regular');

-- 3. اختبار قراءة البيانات
SELECT * FROM public.product_views;

