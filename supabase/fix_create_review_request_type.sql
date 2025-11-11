-- إصلاح: تحديث نوع البيانات في دالة create_review_request
-- المشكلة: operator does not exist: product_type_enum = text
-- الحل: استخدام product_type_enum بدلاً من TEXT

-- حذف جميع النسخ القديمة من دالة create_review_request
DROP FUNCTION IF EXISTS create_review_request(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS create_review_request(TEXT, product_type_enum, TEXT);
DROP FUNCTION IF EXISTS create_review_request(TEXT, TEXT);
DROP FUNCTION IF EXISTS create_review_request;

-- إعادة إنشاء الدالة مع النوع الصحيح
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
    -- الحصول على معرف المستخدم الحالي
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'unauthorized',
            'message', 'يجب تسجيل الدخول أولاً'
        );
    END IF;

    -- التحقق من الحد الأسبوعي (طلب واحد كل 7 أيام)
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

    -- التحقق من عدم وجود طلب نشط لنفس المنتج
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

-- حذف جميع النسخ القديمة من دالة get_active_review_requests
DROP FUNCTION IF EXISTS get_active_review_requests();

-- إنشاء دالة get_active_review_requests بالنوع الصحيح
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
    status TEXT,
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

-- رسالة نجاح
DO $$
BEGIN
    RAISE NOTICE '✅ تم تحديث دالة create_review_request بنوع البيانات الصحيح';
    RAISE NOTICE '✅ تم تحديث دالة get_active_review_requests بنوع البيانات الصحيح';
END $$;
