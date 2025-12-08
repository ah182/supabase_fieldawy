-- دالة موحدة لزيادة المشاهدات لجميع أنواع المنتجات
-- الأنواع المدعومة: 'regular', 'ocr', 'surgical', 'offer', 'book', 'course'

CREATE OR REPLACE FUNCTION increment_unified_view(p_type TEXT, p_id TEXT, p_distributor_name TEXT DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rows_affected INT;
    v_uuid UUID;
    v_offer_id BIGINT;
BEGIN
    -- التحقق من المدخلات الأساسية
    IF p_id IS NULL OR p_type IS NULL THEN
        RETURN FALSE;
    END IF;

    -- 1. معالجة النوع 'regular' (distributor_products)
    IF p_type = 'regular' THEN
        -- المحاولة الأولى: التحديث باستخدام معرف الصف (Primary Key) مباشرة
        UPDATE public.distributor_products
        SET views = COALESCE(views, 0) + 1
        WHERE id = p_id;
        
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
        
        IF v_rows_affected > 0 THEN
            RETURN TRUE;
        END IF;

        -- المحاولة الثانية: التحديث باستخدام معرف المنتج (Catalog ID) واسم الموزع
        UPDATE public.distributor_products
        SET views = COALESCE(views, 0) + 1
        WHERE product_id = p_id
        AND (p_distributor_name IS NULL OR distributor_name = p_distributor_name);
        
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
        RETURN v_rows_affected > 0;

    -- 2. معالجة النوع 'ocr' (distributor_ocr_products)
    ELSIF p_type = 'ocr' THEN
        BEGIN
            v_uuid := p_id::UUID;
            UPDATE public.distributor_ocr_products
            SET views = COALESCE(views, 0) + 1
            WHERE ocr_product_id = v_uuid
            AND (p_distributor_name IS NULL OR distributor_name = p_distributor_name);

            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
            RETURN v_rows_affected > 0;
        EXCEPTION WHEN OTHERS THEN
            -- قد يكون الـ ID هو id الصف وليس ocr_product_id
            UPDATE public.distributor_ocr_products
            SET views = COALESCE(views, 0) + 1
            WHERE id = v_uuid;
            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
            RETURN v_rows_affected > 0;
        END;

    -- 3. معالجة النوع 'surgical' (distributor_surgical_tools)
    ELSIF p_type = 'surgical' THEN
        BEGIN
            v_uuid := p_id::UUID;
            UPDATE public.distributor_surgical_tools
            SET views = COALESCE(views, 0) + 1
            WHERE id = v_uuid;

            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
            RETURN v_rows_affected > 0;
        EXCEPTION WHEN OTHERS THEN
            RETURN FALSE;
        END;

    -- 4. معالجة النوع 'offer' (offers)
    ELSIF p_type = 'offer' OR p_type = 'offers' THEN
        BEGIN
            v_offer_id := p_id::BIGINT;
            UPDATE public.offers
            SET views = COALESCE(views, 0) + 1
            WHERE id = v_offer_id;

            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
            RETURN v_rows_affected > 0;
        EXCEPTION WHEN OTHERS THEN
            RETURN FALSE;
        END;

    -- 5. معالجة النوع 'book' (vet_books)
    ELSIF p_type = 'book' THEN
        BEGIN
            v_uuid := p_id::UUID;
            UPDATE public.vet_books
            SET views = COALESCE(views, 0) + 1
            WHERE id = v_uuid;

            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
            RETURN v_rows_affected > 0;
        EXCEPTION WHEN OTHERS THEN
            RETURN FALSE;
        END;

    -- 6. معالجة النوع 'course' (vet_courses)
    ELSIF p_type = 'course' THEN
        BEGIN
            v_uuid := p_id::UUID;
            UPDATE public.vet_courses
            SET views = COALESCE(views, 0) + 1
            WHERE id = v_uuid;

            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
            RETURN v_rows_affected > 0;
        EXCEPTION WHEN OTHERS THEN
            RETURN FALSE;
        END;

    ELSE
        RETURN FALSE;
    END IF;

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error in increment_unified_view: %', SQLERRM;
    RETURN FALSE;
END;
$$;