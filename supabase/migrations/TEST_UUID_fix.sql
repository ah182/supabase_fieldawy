-- ============================================================================
-- TEST: UUID Fix - اختبار إصلاح UUID
-- Date: 2025-01-23
-- Description: اختبارات للتحقق من عمل الإصلاح
-- ============================================================================

-- ============================================================================
-- 1. التحقق من signature الـ Function
-- ============================================================================

SELECT 
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as parameters,
  pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'create_review_request';

-- يجب أن تشوف:
-- create_review_request | p_product_id text, p_product_type product_type_enum | jsonb

-- ============================================================================
-- 2. اختبار: UUID صالح كـ String
-- ============================================================================

DO $$
DECLARE
  v_result jsonb;
  v_test_uuid text := '12345678-1234-1234-1234-123456789abc';
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🧪 Test 1: Valid UUID as String';
  RAISE NOTICE '   Input: %', v_test_uuid;
  
  v_result := public.create_review_request(
    v_test_uuid,
    'ocr_product'::product_type_enum
  );
  
  IF v_result->>'error' = 'invalid_product_id' THEN
    RAISE NOTICE '   ❌ FAILED: Function does not accept text';
  ELSIF v_result->>'error' = 'product_not_found' THEN
    RAISE NOTICE '   ✅ PASSED: Function accepts text (product not found is OK)';
  ELSIF v_result->>'error' = 'unauthorized' THEN
    RAISE NOTICE '   ✅ PASSED: Function accepts text (need to be logged in)';
  ELSIF v_result->>'success' = 'true' THEN
    RAISE NOTICE '   ✅ PASSED: Request created successfully';
  ELSE
    RAISE NOTICE '   Result: %', v_result;
  END IF;
END $$;

-- ============================================================================
-- 3. اختبار: String غير صالح (يجب أن يفشل بشكل صحيح)
-- ============================================================================

DO $$
DECLARE
  v_result jsonb;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🧪 Test 2: Invalid String (not a UUID)';
  RAISE NOTICE '   Input: "not-a-uuid"';
  
  v_result := public.create_review_request(
    'not-a-uuid',
    'ocr_product'::product_type_enum
  );
  
  IF v_result->>'error' = 'invalid_product_id' THEN
    RAISE NOTICE '   ✅ PASSED: Correctly rejects invalid UUID';
  ELSE
    RAISE NOTICE '   ❌ FAILED: Should reject invalid UUID';
    RAISE NOTICE '   Result: %', v_result;
  END IF;
END $$;

-- ============================================================================
-- 4. اختبار: مع آخر منتج OCR حقيقي
-- ============================================================================

DO $$
DECLARE
  v_result jsonb;
  v_product_id uuid;
  v_product_name text;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🧪 Test 3: With Real OCR Product';
  
  -- جلب آخر منتج OCR
  SELECT id, product_name 
  INTO v_product_id, v_product_name
  FROM public.ocr_products 
  ORDER BY created_at DESC 
  LIMIT 1;
  
  IF v_product_id IS NULL THEN
    RAISE NOTICE '   ⏭️  SKIPPED: No OCR products found';
    RETURN;
  END IF;
  
  RAISE NOTICE '   Product: % (ID: %)', v_product_name, v_product_id;
  
  -- محاولة إنشاء طلب تقييم
  v_result := public.create_review_request(
    v_product_id::text,  -- تحويل UUID إلى text
    'ocr_product'::product_type_enum
  );
  
  IF v_result->>'success' = 'true' THEN
    RAISE NOTICE '   ✅ PASSED: Request created successfully';
    RAISE NOTICE '   Request ID: %', v_result->'data'->>'id';
  ELSIF v_result->>'error' = 'product_already_requested' THEN
    RAISE NOTICE '   ✅ PASSED: Function works (product already has request)';
  ELSIF v_result->>'error' = 'weekly_limit_exceeded' THEN
    RAISE NOTICE '   ✅ PASSED: Function works (weekly limit reached)';
  ELSIF v_result->>'error' = 'unauthorized' THEN
    RAISE NOTICE '   ⚠️  SKIPPED: Need to be authenticated (expected in SQL Editor)';
  ELSE
    RAISE NOTICE '   ❌ FAILED: Unexpected result';
    RAISE NOTICE '   Result: %', v_result;
  END IF;
END $$;

-- ============================================================================
-- 5. التحقق من الـ Parameters في information_schema
-- ============================================================================

DO $$
DECLARE
  v_param_type text;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🔍 Checking Function Parameters:';
  
  SELECT data_type 
  INTO v_param_type
  FROM information_schema.parameters
  WHERE specific_schema = 'public'
    AND specific_name LIKE '%create_review_request%'
    AND parameter_name = 'p_product_id';
  
  IF v_param_type = 'text' OR v_param_type = 'character varying' THEN
    RAISE NOTICE '   ✅ p_product_id type: % (CORRECT)', v_param_type;
  ELSIF v_param_type = 'uuid' THEN
    RAISE NOTICE '   ❌ p_product_id type: uuid (NEEDS FIX)';
  ELSE
    RAISE NOTICE '   ⚠️  p_product_id type: % (UNEXPECTED)', v_param_type;
  END IF;
END $$;

-- ============================================================================
-- 6. تقرير شامل
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '╔═══════════════════════════════════════════╗';
  RAISE NOTICE '║       UUID Fix Test Complete              ║';
  RAISE NOTICE '╚═══════════════════════════════════════════╝';
  RAISE NOTICE '';
  RAISE NOTICE 'If all tests PASSED, the fix is working! ✅';
  RAISE NOTICE 'If any test FAILED, re-run the fix SQL file.';
  RAISE NOTICE '';
END $$;
