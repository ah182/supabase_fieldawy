-- ============================================================================
-- إصلاح حاسم: UUID type mismatch
-- ============================================================================
-- المشكلة: id يجب أن يكون UUID وليس TEXT

-- حذف الدالة القديمة
DROP FUNCTION IF EXISTS get_active_review_requests();

-- إنشاء الدالة بالنوع الصحيح
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
        rr.id::UUID,                   -- ✅ Cast إلى UUID
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
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ تم إصلاح UUID type mismatch';
    RAISE NOTICE '✅ id الآن UUID بدلاً من TEXT';
    RAISE NOTICE '✅ status الآن review_request_status بدلاً من TEXT';
    RAISE NOTICE '✅ get_active_review_requests جاهزة';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 جرب مرة أخرى!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;
