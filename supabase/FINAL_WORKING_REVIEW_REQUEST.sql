-- ============================================================================
-- الإصلاح النهائي الكامل: نظام طلب التقييم مع التعليقات
-- ============================================================================
-- ✅ يحذف الدوال القديمة
-- ✅ يستخدم product_type_enum الصحيح
-- ✅ يستخدم package بدلاً من available_packages
-- ✅ يدعم request_comment

-- الخطوة 1: التأكد من وجود الأعمدة المطلوبة
-- ============================================================================

-- إضافة عمود product_image
ALTER TABLE review_requests 
ADD COLUMN IF NOT EXISTS product_image TEXT;

-- إضافة عمود product_package
ALTER TABLE review_requests 
ADD COLUMN IF NOT EXISTS product_package TEXT;

-- إضافة عمود request_comment
ALTER TABLE review_requests 
ADD COLUMN IF NOT EXISTS request_comment TEXT;

-- إضافة التعليقات
COMMENT ON COLUMN review_requests.product_image IS 'رابط صورة المنتج';
COMMENT ON COLUMN review_requests.product_package IS 'العبوة المحددة للمنتج';
COMMENT ON COLUMN review_requests.request_comment IS 'تعليق طالب التقييم عند إنشاء الطلب';

-- الخطوة 2: حذف جميع النسخ القديمة من الدوال
-- ============================================================================
DROP FUNCTION IF EXISTS create_review_request(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS create_review_request(TEXT, product_type_enum, TEXT);
DROP FUNCTION IF EXISTS create_review_request(TEXT, TEXT);
DROP FUNCTION IF EXISTS create_review_request;

DROP FUNCTION IF EXISTS get_active_review_requests();

-- الخطوة 3: إنشاء دالة create_review_request (الإصدار الصحيح)
-- ============================================================================
CREATE OR REPLACE FUNCTION create_review_request(
    p_product_id TEXT,
    p_product_type product_type_enum DEFAULT 'product',
    p_request_comment TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_product_name TEXT;
    v_product_image TEXT;
    v_product_package TEXT;
    v_request_id TEXT;
    v_weekly_requests_count INT;
    v_existing_request_id TEXT;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'unauthorized',
            'message', 'يجب تسجيل الدخول أولاً'
        );
    END IF;

    SELECT COUNT(*)
    INTO v_weekly_requests_count
    FROM review_requests
    WHERE requested_by = v_user_id
      AND requested_at >= NOW() - INTERVAL '7 days';
    
    IF v_weekly_requests_count >= 1 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'weekly_limit_exceeded',
            'message', 'يمكنك طلب تقييم منتج واحد فقط كل أسبوع'
        );
    END IF;

    SELECT id
    INTO v_existing_request_id
    FROM review_requests
    WHERE product_id = p_product_id
      AND product_type = p_product_type
      AND status = 'active'
    LIMIT 1;
    
    IF v_existing_request_id IS NOT NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'product_already_requested',
            'message', 'يوجد طلب تقييم نشط لهذا المنتج'
        );
    END IF;

    -- الحصول على معلومات المنتج
    IF p_product_type = 'product' THEN
        -- منتج من الكتالوج
        SELECT name, image_url, COALESCE(package, '')
        INTO v_product_name, v_product_image, v_product_package
        FROM products
        WHERE id = p_product_id;
        
    ELSIF p_product_type = 'ocr_product' THEN
        -- منتج OCR
        SELECT product_name, image_url, ''
        INTO v_product_name, v_product_image, v_product_package
        FROM ocr_products
        WHERE id = p_product_id;
        
    ELSIF p_product_type = 'surgical_tool' THEN
        -- أداة جراحية
        SELECT tool_name, image_url, ''
        INTO v_product_name, v_product_image, v_product_package
        FROM surgical_tools
        WHERE id = p_product_id;
        
    ELSE
        RETURN json_build_object(
            'success', false,
            'error', 'invalid_product_type',
            'message', 'نوع المنتج غير صالح'
        );
    END IF;
    
    IF v_product_name IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'product_not_found',
            'message', 'المنتج غير موجود'
        );
    END IF;

    -- إنشاء طلب التقييم مع التعليق
    INSERT INTO review_requests (
        product_id,
        product_type,
        product_name,
        product_image,
        product_package,
        requested_by,
        request_comment,
        status
    )
    VALUES (
        p_product_id,
        p_product_type,
        v_product_name,
        v_product_image,
        v_product_package,
        v_user_id,
        NULLIF(TRIM(p_request_comment), ''),
        'active'
    )
    RETURNING id INTO v_request_id;

    RETURN json_build_object(
        'success', true,
        'request_id', v_request_id,
        'message', 'تم إنشاء طلب التقييم بنجاح'
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'exception',
            'message', SQLERRM
        );
END;
$$;

-- الخطوة 4: إنشاء دالة get_active_review_requests
-- ============================================================================
CREATE OR REPLACE FUNCTION get_active_review_requests()
RETURNS TABLE (
    id UUID,
    product_id TEXT,
    product_type product_type_enum,
    product_name TEXT,
    product_image TEXT,
    product_package TEXT,
    requested_by UUID,
    requester_name TEXT,
    requester_photo TEXT,
    requester_role TEXT,
    status review_request_status,      -- ✅ ENUM بدلاً من TEXT
    comments_count BIGINT,
    total_reviews_count BIGINT,
    avg_rating NUMERIC,
    requested_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    closed_reason TEXT,
    is_comments_full BOOLEAN,
    can_add_comment BOOLEAN,
    request_comment TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH review_counts AS (
        SELECT 
            pr.review_request_id,
            COUNT(*) AS total_count,
            COUNT(*) FILTER (WHERE pr.comment IS NOT NULL AND pr.comment != '') AS comment_count,
            AVG(pr.rating) AS avg_rating
        FROM product_reviews pr
        GROUP BY pr.review_request_id
    )
    SELECT 
        rr.id,
        rr.product_id,
        rr.product_type,
        rr.product_name,
        rr.product_image,
        rr.product_package,
        rr.requested_by,
        u.display_name AS requester_name,
        u.photo_url AS requester_photo,
        u.role AS requester_role,
        rr.status,
        COALESCE(rc.comment_count, 0)::BIGINT AS comments_count,
        COALESCE(rc.total_count, 0)::BIGINT AS total_reviews_count,
        rc.avg_rating,
        rr.requested_at,
        rr.closed_at,
        rr.closed_reason,
        COALESCE(rc.comment_count, 0) >= 5 AS is_comments_full,
        COALESCE(rc.comment_count, 0) < 5 AS can_add_comment,
        rr.request_comment
    FROM review_requests rr
    INNER JOIN users u ON u.id = rr.requested_by
    LEFT JOIN review_counts rc ON rc.review_request_id = rr.id
    WHERE rr.status = 'active'
    ORDER BY rr.requested_at DESC;
END;
$$;

-- الخطوة 5: رسالة نجاح
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ تم إضافة عمود product_image';
    RAISE NOTICE '✅ تم إضافة عمود product_package';
    RAISE NOTICE '✅ تم إضافة عمود request_comment';
    RAISE NOTICE '✅ تم حذف الدوال القديمة';
    RAISE NOTICE '✅ تم إنشاء create_review_request بنوع product_type_enum';
    RAISE NOTICE '✅ تم إنشاء get_active_review_requests مع جميع الحقول';
    RAISE NOTICE '✅ يستخدم package الصحيح (وليس available_packages)';
    RAISE NOTICE '';
    RAISE NOTICE '🎉 جميع الإصلاحات اكتملت!';
    RAISE NOTICE '🚀 جرب إضافة طلب تقييم الآن.';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;
