-- ============================================================================
-- إصلاح أسماء الأعمدة في notification triggers
-- ============================================================================
-- المشكلة: كان الـ trigger يستخدم NEW.user_id 
-- لكن العمود الفعلي اسمه requested_by
-- ============================================================================

-- 1. إعادة إنشاء Function لإرسال webhook لطلبات التقييم (مصححة)
CREATE OR REPLACE FUNCTION notify_new_review_request()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url text;
  v_product_name text;
  v_requester_name text;
  v_payload json;
BEGIN
  -- جلب معلومات المنتج
  IF NEW.product_type = 'product' THEN
    SELECT name INTO v_product_name
    FROM products
    WHERE id::text = NEW.product_id
    LIMIT 1;
  ELSIF NEW.product_type = 'ocr_product' THEN
    SELECT product_name INTO v_product_name
    FROM ocr_products
    WHERE id::text = NEW.product_id
    LIMIT 1;
  ELSIF NEW.product_type = 'surgical_tool' THEN
    SELECT tool_name INTO v_product_name
    FROM surgical_tools
    WHERE id::text = NEW.product_id
    LIMIT 1;
  END IF;

  -- جلب اسم صاحب الطلب (العمود الصحيح: requested_by)
  SELECT COALESCE(display_name, email, 'مستخدم')
  INTO v_requester_name
  FROM users
  WHERE id = NEW.requested_by  -- ✅ تصحيح: requested_by بدلاً من user_id
  LIMIT 1;

  -- بناء الـ payload
  v_payload := json_build_object(
    'type', 'INSERT',
    'table', 'review_requests',
    'record', json_build_object(
      'id', NEW.id,
      'product_id', NEW.product_id,
      'product_type', NEW.product_type,
      'product_name', COALESCE(v_product_name, 'منتج'),
      'requester_name', COALESCE(v_requester_name, 'مستخدم'),
      'user_id', NEW.requested_by,  -- ✅ للتوافق مع الـ Worker
      'created_at', NEW.created_at
    )
  );

  -- إرسال الـ webhook
  v_webhook_url := current_setting('app.settings.webhook_url', true);
  
  IF v_webhook_url IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_webhook_url,
      body := v_payload::text
    );
    
    RAISE NOTICE '📤 webhook sent for new review request: %', v_product_name;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Function للتعليقات تبقى كما هي (العمود صحيح: user_id)
-- لكن نتأكد من استخدام العمود الصحيح
CREATE OR REPLACE FUNCTION notify_new_product_review()
RETURNS TRIGGER AS $$
DECLARE
  v_webhook_url text;
  v_product_name text;
  v_reviewer_name text;
  v_comment_preview text;
  v_payload json;
BEGIN
  -- تجاهل التحديثات، فقط للإضافات الجديدة
  IF TG_OP = 'UPDATE' THEN
    RETURN NEW;
  END IF;

  -- تجاهل لو مفيش تعليق
  IF NEW.comment IS NULL OR NEW.comment = '' THEN
    RETURN NEW;
  END IF;

  -- جلب اسم المنتج من review_requests
  SELECT product_name INTO v_product_name
  FROM review_requests
  WHERE id = NEW.review_request_id
  LIMIT 1;

  -- جلب اسم المعلق (✅ user_id صحيح في جدول product_reviews)
  SELECT COALESCE(display_name, email, 'مستخدم')
  INTO v_reviewer_name
  FROM users
  WHERE id = NEW.user_id
  LIMIT 1;

  -- معاينة التعليق (أول 100 حرف)
  v_comment_preview := CASE 
    WHEN length(NEW.comment) > 100 THEN substring(NEW.comment, 1, 100) || '...'
    ELSE NEW.comment
  END;

  -- بناء الـ payload
  v_payload := json_build_object(
    'type', 'INSERT',
    'table', 'product_reviews',
    'record', json_build_object(
      'id', NEW.id,
      'review_request_id', NEW.review_request_id,
      'product_id', NEW.product_id,
      'product_type', NEW.product_type,
      'product_name', COALESCE(v_product_name, 'منتج'),
      'reviewer_name', COALESCE(v_reviewer_name, 'مستخدم'),
      'rating', NEW.rating,
      'comment', v_comment_preview,
      'user_id', NEW.user_id,
      'created_at', NEW.created_at
    )
  );

  -- إرسال الـ webhook
  v_webhook_url := current_setting('app.settings.webhook_url', true);
  
  IF v_webhook_url IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_webhook_url,
      body := v_payload::text
    );
    
    RAISE NOTICE '📤 webhook sent for new review from: %', v_reviewer_name;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. رسالة تأكيد
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ تم إصلاح notification triggers!';
  RAISE NOTICE '📝 التغييرات:';
  RAISE NOTICE '   - استخدام requested_by بدلاً من user_id في review_requests';
  RAISE NOTICE '   - user_id لا يزال صحيحاً في product_reviews';
  RAISE NOTICE '';
  RAISE NOTICE '🧪 جرب الآن إضافة طلب تقييم!';
  RAISE NOTICE '';
END $$;
