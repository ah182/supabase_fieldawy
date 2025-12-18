-- Fix for: operator does not exist: text = uuid
-- This handles both TEXT IDs (products) and UUID IDs (ocr_products, surgical_tools)

CREATE OR REPLACE FUNCTION create_review_request(
    p_product_id TEXT,
    p_product_type product_type_enum DEFAULT 'product',
    p_request_comment TEXT DEFAULT NULL,
    p_custom_name TEXT DEFAULT NULL,
    p_custom_image TEXT DEFAULT NULL,
    p_custom_package TEXT DEFAULT NULL
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

    -- التحقق من عدم وجود طلب نشط لنفس المنتج (فقط للمنتجات التي لها معرف حقيقي)
    IF p_product_id != 'temp_ocr' THEN
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
    END IF;

    -- الحصول على معلومات المنتج
    -- إذا تم تمرير بيانات مخصصة (OCR الجديد)، نستخدمها مباشرة
    IF p_custom_name IS NOT NULL THEN
        v_product_name := p_custom_name;
        v_product_image := p_custom_image;
        v_product_package := COALESCE(p_custom_package, '');
    ELSIF p_product_type = 'product' THEN
        -- منتج من الكتالوج (معرف نصي)
        SELECT name, image_url, COALESCE(package, '')
        INTO v_product_name, v_product_image, v_product_package
        FROM products
        WHERE id = p_product_id;
        
    ELSIF p_product_type = 'ocr_product' THEN
        -- منتج OCR (معرف UUID)
        IF p_product_id ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
            SELECT product_name, image_url, ''
            INTO v_product_name, v_product_image, v_product_package
            FROM ocr_products
            WHERE id = p_product_id::uuid;
        END IF;
        
    ELSIF p_product_type = 'surgical_tool' THEN
        -- أداة جراحية (معرف UUID)
        IF p_product_id ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
            SELECT tool_name, image_url, ''
            INTO v_product_name, v_product_image, v_product_package
            FROM surgical_tools
            WHERE id = p_product_id::uuid;
        END IF;
    END IF;
    
    IF v_product_name IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'product_not_found',
            'message', 'المنتج غير موجود'
        );
    END IF;

    -- إنشاء طلب التقييم
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
