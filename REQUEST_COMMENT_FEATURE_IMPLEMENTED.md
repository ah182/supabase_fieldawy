# إضافة تعليق مع طلب التقييم - تم ✅

## الوصف
تم إضافة إمكانية كتابة تعليق **بعد اختيار المنتج مباشرة** في صفحة التقييمات. يظهر dialog جميل يحتوي على صورة المنتج وحقل التعليق، ويتم عرض التعليق مع الطلب في قائمة الطلبات وصفحة التفاصيل.

## التدفق الجديد 🔄
1. المستخدم يضغط على "إضافة طلب تقييم" ➜
2. يختار مصدر المنتج (كتالوج أو معرض) ➜
3. يختار المنتج ➜
4. **يظهر dialog جديد** يحتوي على:
   - 🖼️ صورة المنتج (120×120)
   - 📝 اسم المنتج
   - 💬 حقل TextField للتعليق (اختياري، حتى 300 حرف، autofocus)
   - ✅ زر "إرسال الطلب"
5. يتم إرسال الطلب مع التعليق ✅

## التعديلات التي تمت 📝

### 1. قاعدة البيانات (SQL) 🗄️
**الملف**: `supabase/add_request_comment_to_reviews.sql`

#### التغييرات:
- ✅ إضافة عمود `request_comment TEXT` إلى جدول `review_requests`
- ✅ تحديث دالة `create_review_request` لقبول parameter جديد `p_request_comment`
- ✅ تحديث دالة `get_active_review_requests` لإرجاع `request_comment`

```sql
-- إضافة العمود
ALTER TABLE review_requests 
ADD COLUMN IF NOT EXISTS request_comment TEXT;

-- تحديث دالة create_review_request
CREATE OR REPLACE FUNCTION create_review_request(
    p_product_id TEXT,
    p_product_type TEXT DEFAULT 'product',
    p_request_comment TEXT DEFAULT NULL  -- جديد
)
...

-- تحديث دالة get_active_review_requests
CREATE OR REPLACE FUNCTION get_active_review_requests()
RETURNS TABLE (
    ...
    request_comment TEXT  -- جديد
)
...
```

---

### 2. Review Model 📦
**الملف**: `lib/features/reviews/review_system.dart`

#### إضافة حقل requestComment إلى ReviewRequestModel:

```dart
class ReviewRequestModel {
  ...
  final String? requestComment; // جديد: تعليق طالب التقييم

  ReviewRequestModel({
    ...
    this.requestComment, // جديد
  });

  factory ReviewRequestModel.fromJson(Map<String, dynamic> json) {
    return ReviewRequestModel(
      ...
      requestComment: json['request_comment'] as String?, // جديد
    );
  }
}
```

---

### 3. Review Service 🔧
**الملف**: `lib/features/reviews/review_system.dart`

#### تحديث createReviewRequest method:

```dart
Future<Map<String, dynamic>> createReviewRequest({
  required String productId,
  String productType = 'product',
  String? requestComment, // جديد: تعليق طالب التقييم
}) async {
  try {
    final response = await _supabase.rpc(
      'create_review_request',
      params: {
        'p_product_id': productId,
        'p_product_type': productType,
        'p_request_comment': requestComment, // جديد: إرسال التعليق
      },
    );
    ...
  }
}
```

---

### 4. UI - Dialog اختيار المصدر 🎨
**الملف**: `lib/features/reviews/products_reviews_screen.dart`

#### تبسيط Dialog اختيار المصدر:

تم إزالة حقل التعليق من dialog اختيار المصدر، وأصبح يعرض فقط خيارات المصدر (كتالوج أو معرض).

### 5. UI - Dialog التعليق الجديد 💬
**الملف**: `lib/features/reviews/products_reviews_screen.dart`

#### إضافة Dialog جديد يظهر بعد اختيار المنتج:

```dart
void _showCommentDialog(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> selectedProduct,
) {
  final commentController = TextEditingController();
  final colorScheme = Theme.of(context).colorScheme;
  
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('أضف تعليقك'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // صورة المنتج
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: selectedProduct['product_image'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: colorScheme.surfaceVariant,
                    child: Icon(Icons.medication, size: 48),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // اسم المنتج
            Text(
              selectedProduct['product_name'] ?? 'منتج',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            
            // حقل التعليق
            TextField(
              controller: commentController,
              maxLines: 4,
              maxLength: 300,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'تعليقك على المنتج (اختياري)',
                hintText: 'مثال: أريد معرفة جودة هذا المنتج وسعره في السوق',
                helperText: 'سيظهر تعليقك مع طلب التقييم',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.comment),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(dialogContext);
            _createReviewRequestFromSelection(
              context,
              ref,
              selectedProduct,
              commentController.text.trim(),
            );
          },
          icon: const Icon(Icons.send),
          label: const Text('إرسال الطلب'),
        ),
      ],
    ),
  );
}
```

#### تحديث إرسال الطلب:

```dart
Future<void> _createReviewRequestFromSelection(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> selectedProduct,
  String requestComment, // جديد: parameter للتعليق
) async {
  ...
  final result = await service.createReviewRequest(
    productId: selectedProduct['product_id'],
    productType: selectedProduct['product_type'],
    requestComment: requestComment.isEmpty ? null : requestComment, // جديد
  );
  ...
}
```

---

### 5. UI - عرض التعليق في الكارد 📋
**الملف**: `lib/features/reviews/products_reviews_screen.dart`

#### في ProductReviewCard:

```dart
// تعليق طالب التقييم (إذا كان موجوداً)
if (request.requestComment != null && request.requestComment!.isNotEmpty) ...[
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colorScheme.surfaceVariant.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: colorScheme.outline.withOpacity(0.3),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.chat_bubble_outline,
          size: 18,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تعليق طالب التقييم:',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                request.requestComment!,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    ),
  ),
  const SizedBox(height: 12),
],
```

---

### 6. UI - عرض التعليق في صفحة التفاصيل 📄
**الملف**: `lib/features/reviews/products_reviews_screen.dart`

#### في ProductReviewDetailsScreen:

نفس التصميم المستخدم في الكارد، مع margin للتوسيط.

---

## كيفية الاستخدام 🚀

### خطوات تطبيق التحديث:

#### 1. تطبيق SQL Script
انتقل إلى **Supabase Dashboard** → **SQL Editor** وقم بتشغيل:

```
supabase/add_request_comment_to_reviews.sql
```

#### 2. اختبار الميزة

1. **افتح التطبيق** وانتقل إلى صفحة **التقييمات**
2. **اضغط على زر** "إضافة طلب تقييم" (+)
3. **اكتب تعليقك** في الحقل الجديد (اختياري)
4. **اختر المنتج** من الكتالوج أو المعرض
5. **سيتم إنشاء الطلب** مع التعليق

#### 3. عرض التعليق

- **في قائمة الطلبات**: سيظهر التعليق تحت معلومات المنتج
- **في صفحة التفاصيل**: سيظهر التعليق أعلى الإحصائيات

---

## الميزات الجديدة ✨

### 1. حقل التعليق الاختياري
- ✅ يمكن للمستخدم إضافة تعليق (حتى 300 حرف)
- ✅ الحقل اختياري - يمكن تركه فارغاً
- ✅ يظهر hint text لتوجيه المستخدم

### 2. عرض التعليق في القائمة
- ✅ يظهر التعليق في كارد الطلب
- ✅ تصميم مميز مع أيقونة chat bubble
- ✅ يظهر فقط إذا كان التعليق موجوداً

### 3. عرض التعليق في صفحة التفاصيل
- ✅ يظهر التعليق أعلى الإحصائيات
- ✅ نفس التصميم المتناسق مع الكارد

---

## الملفات المعدلة 📁

| الملف | التغييرات |
|------|-----------|
| `supabase/add_request_comment_to_reviews.sql` | ✅ جديد - SQL script |
| `lib/features/reviews/review_system.dart` | ✅ ReviewRequestModel + ReviewService |
| `lib/features/reviews/products_reviews_screen.dart` | ✅ UI + Dialog + Cards |

**المجموع**: 3 ملفات (1 جديد + 2 محدثين)

---

## الفوائد 🎯

1. **تواصل أفضل**: المستخدمون يمكنهم توضيح سبب طلب التقييم
2. **سياق أوضح**: المقيمون يفهمون ما يبحث عنه طالب التقييم
3. **تجربة محسنة**: معلومات إضافية تساعد في تقديم تقييمات أفضل
4. **مرونة**: الحقل اختياري - لا يجبر المستخدم على كتابة تعليق

---

## مثال على الاستخدام 💡

**المستخدم يطلب تقييم منتج "أموكسيسيلين 500mg":**

تعليقه:
```
أريد معرفة جودة هذا المنتج وسعره المناسب في السوق. 
هل هو فعال للقطط الصغيرة؟
```

**النتيجة**:
- يظهر التعليق مع الطلب في القائمة
- المقيمون يرون التعليق ويعطون تقييمات مركزة على الأسئلة المطروحة
- تجربة أفضل للجميع! ✨

---

## ملاحظات 📌

- ✅ التعليق اختياري (nullable)
- ✅ الحد الأقصى 300 حرف
- ✅ يظهر فقط إذا كان موجوداً وغير فارغ
- ✅ يدعم النصوص العربية والإنجليزية
- ✅ تصميم متناسق مع باقي الواجهة

---

## الاختبار ✅

للتأكد من عمل الميزة:

1. ✅ إنشاء طلب تقييم **مع** تعليق
2. ✅ إنشاء طلب تقييم **بدون** تعليق
3. ✅ التحقق من ظهور التعليق في القائمة
4. ✅ التحقق من ظهور التعليق في صفحة التفاصيل
5. ✅ التحقق من عدم ظهور قسم التعليق إذا كان فارغاً
