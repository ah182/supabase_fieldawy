-- تطوير دالة إنشاء طلب التقييم لدعم المنتجات الجديدة دون حفظها في ocr_products
-- Fix for: avoiding ocr_products clutter when requesting reviews

CREATE OR REPLACE FUNCTION create_review_request(
    p_product_id TEXT DEFAULT NULL,
    p_product_type TEXT DEFAULT 'product',
    p_request_comment TEXT DEFAULT NULL,
    p_product_name TEXT DEFAULT NULL, -- بارامتر جديد
    p_product_image TEXT DEFAULT NULL, -- بارامتر جديد
    p_product_package TEXT DEFAULT NULL -- بارامتر جديد
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_final_name TEXT;
    v_final_image TEXT;
    v_final_package TEXT;
    v_request_id UUID;
    v_weekly_requests_count INT;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'unauthorized', 'message', 'يجب تسجيل الدخول أولاً');
    END IF;

    -- التحقق من الحد الأسبوعي
    SELECT COUNT(*) INTO v_weekly_requests_count FROM review_requests
    WHERE requested_by = v_user_id AND requested_at >= NOW() - INTERVAL '7 days';
    
    IF v_weekly_requests_count >= 1 THEN
        RETURN json_build_object('success', false, 'error', 'weekly_limit_exceeded', 'message', 'يمكنك طلب تقييم منتج واحد فقط كل أسبوع');
    END IF;

    -- إذا كان المنتج جديداً (من الجالري ولم يتم حفظه)
    IF p_product_type = 'new_ocr_request' THEN
        v_final_name := p_product_name;
        v_final_image := p_product_image;
        v_final_package := COALESCE(p_product_package, '');
        
        IF v_final_name IS NULL OR v_final_name = '' THEN
            RETURN json_build_object('success', false, 'error', 'missing_data', 'message', 'اسم المنتج مطلوب');
        END IF;
    ELSE
        -- المنطق القديم للمنتجات الموجودة مسبقاً
        IF p_product_type = 'product' THEN
            SELECT name, image_url, COALESCE(package, '') INTO v_final_name, v_final_image, v_final_package
            FROM products WHERE id::text = p_product_id;
        ELSIF p_product_type = 'ocr_product' THEN
            SELECT product_name, image_url, package INTO v_final_name, v_final_image, v_final_package
            FROM ocr_products WHERE id::text = p_product_id;
        ELSIF p_product_type = 'surgical_tool' THEN
            SELECT tool_name, image_url, '' INTO v_final_name, v_final_image, v_final_package
            FROM surgical_tools WHERE id::text = p_product_id;
        END IF;
    END IF;
    
    IF v_final_name IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'product_not_found', 'message', 'المنتج غير موجود');
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
        COALESCE(p_product_id, 'temp_' || gen_random_uuid()::text),
        CASE WHEN p_product_type = 'new_ocr_request' THEN 'ocr_product'::product_type_enum ELSE p_product_type::product_type_enum END,
        v_final_name,
        v_final_image,
        v_final_package,
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
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', 'exception', 'message', SQLERRM);
END;
$$;
