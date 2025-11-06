-- =====================================================
-- إضافة عمود views لجميع الجداول
-- =====================================================

-- =====================================================
-- 1. distributor_products
-- =====================================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'distributor_products' AND column_name = 'views'
    ) THEN
        ALTER TABLE distributor_products ADD COLUMN views INTEGER DEFAULT 0;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_distributor_products_views 
ON distributor_products(views DESC);

-- =====================================================
-- 2. distributor_ocr_products
-- =====================================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'distributor_ocr_products' AND column_name = 'views'
    ) THEN
        ALTER TABLE distributor_ocr_products ADD COLUMN views INTEGER DEFAULT 0;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_distributor_ocr_products_views 
ON distributor_ocr_products(views DESC);

-- =====================================================
-- 3. distributor_surgical_tools
-- =====================================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'distributor_surgical_tools' AND column_name = 'views'
    ) THEN
        ALTER TABLE distributor_surgical_tools ADD COLUMN views INTEGER DEFAULT 0;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_distributor_surgical_tools_views 
ON distributor_surgical_tools(views DESC);

-- =====================================================
-- 4. offers
-- =====================================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'offers' AND column_name = 'views'
    ) THEN
        ALTER TABLE offers ADD COLUMN views INTEGER DEFAULT 0;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_offers_views 
ON offers(views DESC);

-- =====================================================
-- 5. courses (إذا كان الجدول موجوداً)
-- =====================================================
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'courses'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'courses' AND column_name = 'views'
        ) THEN
            ALTER TABLE courses ADD COLUMN views INTEGER DEFAULT 0;
        END IF;
        
        CREATE INDEX IF NOT EXISTS idx_courses_views 
        ON courses(views DESC);
    END IF;
END $$;

-- =====================================================
-- 6. books (إذا كان الجدول موجوداً)
-- =====================================================
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'books'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'books' AND column_name = 'views'
        ) THEN
            ALTER TABLE books ADD COLUMN views INTEGER DEFAULT 0;
        END IF;
        
        CREATE INDEX IF NOT EXISTS idx_books_views 
        ON books(views DESC);
    END IF;
END $$;

-- =====================================================
-- 7. تحديث القيم الحالية إلى 0 إذا كانت null
-- =====================================================
UPDATE distributor_products SET views = 0 WHERE views IS NULL;
UPDATE distributor_ocr_products SET views = 0 WHERE views IS NULL;
UPDATE distributor_surgical_tools SET views = 0 WHERE views IS NULL;
UPDATE offers SET views = 0 WHERE views IS NULL;

-- تحديث courses و books إذا كانت موجودة
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'courses') THEN
        UPDATE courses SET views = 0 WHERE views IS NULL;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'books') THEN
        UPDATE books SET views = 0 WHERE views IS NULL;
    END IF;
END $$;

-- =====================================================
-- 8. إضافة constraints للتأكد من أن views لا تكون سالبة
-- =====================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'distributor_products' 
        AND constraint_name = 'check_views_non_negative'
    ) THEN
        ALTER TABLE distributor_products 
        ADD CONSTRAINT check_views_non_negative 
        CHECK (views >= 0);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'distributor_ocr_products' 
        AND constraint_name = 'check_ocr_views_non_negative'
    ) THEN
        ALTER TABLE distributor_ocr_products 
        ADD CONSTRAINT check_ocr_views_non_negative 
        CHECK (views >= 0);
    END IF;
END $$;

