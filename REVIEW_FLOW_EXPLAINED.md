# 🔄 شرح مسار إضافة طلب تقييم كامل

## 📍 المسار من البداية للنهاية:

### الخطوة 1️⃣: المستخدم يضغط زر ➕ (إضافة طلب تقييم)
📁 **الملف:** `lib/features/reviews/products_reviews_screen.dart`
📌 **الدالة:** `_showAddReviewRequestDialog()`

```dart
// يظهر Dialog فيه خيارين:
- من الكتالوج
- من المعرض
```

---

### الخطوة 2️⃣: المستخدم يختار "من المعرض"
📁 **الملف:** `lib/features/products/presentation/screens/add_product_ocr_screen.dart`
📌 **الدالة:** `_saveProduct()`

```dart
// عند isFromReviewRequest = true:
if (widget.isFromReviewRequest) {
  // يضيف المنتج في جدول ocr_products
  final ocrProductId = await productRepo.addOcrProduct(
    distributorId: userId,
    distributorName: distributorName,
    productName: name,        // ⚠️ مهم!
    productCompany: company,
    activePrinciple: activePrinciple,
    package: package,
    imageUrl: finalUrl,
  );

  // يرجع البيانات
  Navigator.pop(context, {
    'product_id': ocrProductId,
    'product_type': 'ocr_product',
  });
}
```

📊 **جدول Supabase:** `ocr_products`
```sql
-- يحفظ في:
INSERT INTO ocr_products (
  id,                     -- UUID تلقائي
  distributor_id,         -- من المستخدم
  distributor_name,       -- من المستخدم
  product_name,           -- ⚠️ اسم المنتج (مهم!)
  product_company,        -- الشركة
  active_principle,       -- المادة الفعالة
  package,                -- العبوة
  image_url               -- صورة
);
```

---

### الخطوة 3️⃣: النظام يرجع للصفحة الرئيسية
📁 **الملف:** `lib/features/reviews/products_reviews_screen.dart`
📌 **الدالة:** `_createReviewRequestFromSelection()`

```dart
// ياخذ البيانات المرجوعة:
{
  'product_id': 'uuid-here',
  'product_type': 'ocr_product'
}

// يستدعي الـ service:
final result = await service.createReviewRequest(
  productId: selectedProduct['product_id'],
  productType: selectedProduct['product_type'],
);
```

---

### الخطوة 4️⃣: الـ Service يستدعي Supabase Function
📁 **الملف:** `lib/features/reviews/review_system.dart`
📌 **الدالة:** `createReviewRequest()`

```dart
final response = await _supabase.rpc(
  'create_review_request',  // ⚠️ استدعاء function في Supabase
  params: {
    'p_product_id': productId,
    'p_product_type': productType,
  },
);
```

---

### الخطوة 5️⃣: Supabase Function تنفذ المنطق
📁 **الملف:** `supabase/migrations/20250123_review_system_functions.sql`
📌 **الـ Function:** `create_review_request()`

```sql
CREATE OR REPLACE FUNCTION public.create_review_request(
  p_product_id uuid,
  p_product_type product_type_enum DEFAULT 'product'
)
RETURNS jsonb AS $$
DECLARE
  v_product_name text;
BEGIN
  -- 1. جلب اسم المنتج حسب النوع
  IF p_product_type = 'product' THEN
    SELECT name INTO v_product_name
    FROM public.products
    WHERE id = p_product_id;
  ELSE
    -- ⚠️ مهم جداً! يجلب من ocr_products
    SELECT product_name INTO v_product_name
    FROM public.ocr_products
    WHERE id = p_product_id;
  END IF;
  
  -- 2. حفظ في جدول review_requests
  INSERT INTO public.review_requests (
    product_id,
    product_type,
    product_name,      -- ⚠️ يحفظ الاسم هنا
    requested_by,
    requester_name,
    status
  ) VALUES (
    p_product_id,
    p_product_type,
    v_product_name,    -- ⚠️ من ocr_products
    v_user_id,
    v_user_name,
    'active'
  );
END;
$$;
```

📊 **جدول Supabase:** `review_requests`
```sql
-- يحفظ في:
INSERT INTO review_requests (
  id,                  -- UUID تلقائي
  product_id,          -- من الخطوة 2
  product_type,        -- 'ocr_product'
  product_name,        -- ⚠️ من ocr_products
  requested_by,        -- user_id
  requester_name,      -- اسم المستخدم
  status,              -- 'active'
  comments_count,      -- 0
  total_reviews_count, -- 0
  avg_rating,          -- NULL
  requested_at,        -- now()
  created_at           -- now()
);
```

---

### الخطوة 6️⃣: الصفحة تعرض البيانات
📁 **الملف:** `lib/features/reviews/products_reviews_screen.dart`
📌 **الـ Provider:** `activeReviewRequestsProvider`

```dart
final activeReviewRequestsProvider = FutureProvider<List<ReviewRequestModel>>((ref) async {
  final response = await Supabase.instance.client
      .from('review_requests')        // ⚠️ يقرأ من هنا
      .select('*')
      .eq('status', 'active')
      .order('requested_at', ascending: false);
  
  return (response as List)
      .map((json) => ReviewRequestModel.fromJson(json))
      .toList();
});
```

📌 **الشاشة:** `ProductsWithReviewsScreen`
```dart
// تعرض القائمة:
ListView.builder(
  itemCount: requests.length,
  itemBuilder: (context, index) {
    final request = requests[index];
    return ProductReviewCard(
      productName: request.productName,    // ⚠️ من review_requests
      avgRating: request.avgRating,
      reviewsCount: request.totalReviewsCount,
      // ...
    );
  },
);
```

---

## ✅ الخلاصة - أين يحفظ المنتج؟

| الخطوة | الجدول | البيانات المحفوظة |
|--------|--------|-------------------|
| 2️⃣ | `ocr_products` | المنتج الكامل (اسم، شركة، صورة، إلخ) |
| 5️⃣ | `review_requests` | طلب التقييم (product_id + product_name) |

---

## 🔍 كيف تتحقق أن المنتج ظهر؟

### 1️⃣ في Supabase Dashboard:

**تحقق من `ocr_products`:**
```sql
SELECT * FROM public.ocr_products
ORDER BY created_at DESC
LIMIT 5;
```

**تحقق من `review_requests`:**
```sql
SELECT 
  id,
  product_id,
  product_type,
  product_name,
  status,
  requested_at
FROM public.review_requests
WHERE status = 'active'
ORDER BY requested_at DESC;
```

### 2️⃣ في التطبيق:

افتح **Flutter DevTools** وشوف:
```dart
// في Console:
ref.read(activeReviewRequestsProvider)
```

---

## ❓ إذا المنتج لم يظهر - الأسباب المحتملة:

### ❌ السبب 1: RLS غير مفعل
```sql
-- الحل:
ALTER TABLE public.review_requests ENABLE ROW LEVEL SECURITY;

-- أضف policy:
CREATE POLICY review_requests_select_authenticated
  ON public.review_requests
  FOR SELECT
  TO authenticated
  USING (true);
```

### ❌ السبب 2: اسم المنتج NULL
```sql
-- تحقق:
SELECT 
  id, 
  product_name,
  product_id,
  product_type
FROM review_requests
WHERE product_name IS NULL;

-- إذا وجدت صفوف، السبب:
-- الـ function لم تجد المنتج في ocr_products
```

### ❌ السبب 3: Provider لا يُحدث
```dart
// في الكود، بعد النجاح:
ref.invalidate(activeReviewRequestsProvider); // ⚠️ تأكد من هذا السطر
```

### ❌ السبب 4: الـ Status ليس 'active'
```sql
-- تحقق:
SELECT status, COUNT(*) 
FROM review_requests 
GROUP BY status;

-- يجب أن يكون:
-- active | 1 (أو أكثر)
```

---

## 🧪 اختبار سريع:

### في Supabase SQL Editor:

```sql
-- 1. شوف آخر منتج OCR:
SELECT * FROM ocr_products 
ORDER BY created_at DESC 
LIMIT 1;

-- 2. شوف آخر طلب تقييم:
SELECT * FROM review_requests 
ORDER BY created_at DESC 
LIMIT 1;

-- 3. تحقق من الربط:
SELECT 
  rr.id,
  rr.product_name,
  rr.product_type,
  op.product_name as ocr_product_name,
  p.name as regular_product_name
FROM review_requests rr
LEFT JOIN ocr_products op ON op.id = rr.product_id AND rr.product_type = 'ocr_product'
LEFT JOIN products p ON p.id = rr.product_id AND rr.product_type = 'product'
ORDER BY rr.created_at DESC
LIMIT 5;
```

---

## 🎯 المسار الصحيح (ملخص):

```
المستخدم → Dialog → OCR Screen → addOcrProduct()
                                        ↓
                                   ocr_products table
                                        ↓
                    ← يرجع product_id ←
                           ↓
            createReviewRequest() → Supabase Function
                           ↓
                    review_requests table
                           ↓
            activeReviewRequestsProvider
                           ↓
            ProductsWithReviewsScreen
```

---

## 🚀 الخطوة التالية:

1. شغل الاستعلام في Supabase للتحقق
2. تأكد من RLS
3. جرب إضافة منتج جديد
4. شوف الـ logs في Flutter Console

إذا لم يظهر، شاركني:
- نتيجة الاستعلامات من Supabase
- الـ logs من Flutter Console
- Screenshot من الصفحة
