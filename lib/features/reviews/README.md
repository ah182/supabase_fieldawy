# 🌟 Review System - دليل الاستخدام

## 📁 الملف الشامل
تم إنشاء نظام التقييمات بالكامل في ملف واحد: `review_system.dart`

يحتوي على:
- ✅ Models (ReviewRequest, ProductReview)
- ✅ Service (جميع الدوال)
- ✅ Providers (Riverpod)
- ✅ Widgets (RatingStars, ReviewCard, etc.)
- ✅ Screens (3 شاشات كاملة)

---

## 🚀 التثبيت والإعداد

### 1. تنفيذ SQL
```bash
# في Supabase Dashboard -> SQL Editor
# شغل الملفات بالترتيب:
1. supabase/migrations/20250123_create_review_system.sql
2. supabase/migrations/20250123_review_system_rls.sql
3. supabase/migrations/20250123_review_system_functions.sql
4. supabase/migrations/20250123_review_system_views.sql
```

### 2. إضافة Import
في أي ملف تريد استخدام النظام فيه:

```dart
import 'package:fieldawy_store/features/reviews/review_system.dart';
```

---

## 💡 الاستخدام

### 1. عرض طلبات التقييم النشطة
```dart
// في أي مكان في التطبيق
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const ActiveReviewRequestsScreen(),
  ),
);
```

### 2. زر طلب تقييم في صفحة المنتج
```dart
// في صفحة تفاصيل المنتج
CreateReviewRequestButton(
  productId: product.id,
  productType: 'product', // أو 'ocr_product'
)
```

### 3. عرض تقييمات منتج محدد
```dart
// إذا عندك ReviewRequestModel
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ProductReviewsScreen(request: reviewRequest),
  ),
);
```

### 4. استخدام الـ Providers مباشرة
```dart
// جلب طلبات التقييم النشطة
final requestsAsync = ref.watch(activeReviewRequestsProvider);

// جلب تقييمات منتج
final reviewsAsync = ref.watch(productReviewsProvider((
  productId: 'product-uuid',
  productType: 'product',
)));

// التحقق من وجود طلب لمنتج
final requestAsync = ref.watch(requestByProductProvider((
  productId: 'product-uuid',
  productType: 'product',
)));
```

---

## 🎨 الـ Widgets الجاهزة

### RatingStars
```dart
RatingStars(
  rating: 4.5,
  size: 20,
  showNumber: true,
)
```

### RatingInput
```dart
RatingInput(
  initialRating: 0,
  onRatingChanged: (rating) {
    print('Selected rating: $rating');
  },
  size: 32,
)
```

### ReviewRequestCard
```dart
ReviewRequestCard(
  request: reviewRequest,
  onTap: () {
    // Navigate to reviews screen
  },
)
```

### ProductReviewCard
```dart
ProductReviewCard(
  review: productReview,
)
```

---

## 🔧 استخدام الـ Service مباشرة

```dart
final service = ref.read(reviewServiceProvider);

// إنشاء طلب تقييم
final result = await service.createReviewRequest(
  productId: 'uuid',
  productType: 'product',
);

// إضافة تقييم
final result = await service.addProductReview(
  requestId: 'uuid',
  rating: 5,
  comment: 'منتج رائع!',
);

// التصويت على فائدة التقييم
await service.voteReviewHelpful(
  reviewId: 'uuid',
  isHelpful: true,
);

// الإبلاغ عن تقييم
await service.reportReview(
  reviewId: 'uuid',
  reason: 'محتوى غير لائق',
);

// حذف تقييمي
await service.deleteMyReview('uuid');
```

---

## 📱 دمج في الصفحات الحالية

### في صفحة تفاصيل المنتج
```dart
// أضف في أسفل الصفحة
Column(
  children: [
    // معلومات المنتج الحالية
    // ...
    
    const SizedBox(height: 16),
    
    // زر طلب التقييم / عرض التقييمات
    CreateReviewRequestButton(
      productId: product.id,
      productType: 'product',
    ),
  ],
)
```

### في الـ Home Screen (علامة تبويب جديدة)
```dart
// في TabBar
tabs: [
  Tab(text: 'الرئيسية'),
  Tab(text: 'الأسعار'),
  Tab(text: 'التقييمات'), // جديد
],

// في TabBarView
children: [
  HomeTab(),
  PricesTab(),
  ActiveReviewRequestsScreen(), // جديد
],
```

### في صفحة المنتج (عرض Badge التقييم)
```dart
Consumer(
  builder: (context, ref, child) {
    final requestAsync = ref.watch(requestByProductProvider((
      productId: product.id,
      productType: 'product',
    )));
    
    return requestAsync.maybeWhen(
      data: (request) {
        if (request != null && request.avgRating != null) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: 14, color: Colors.amber),
                SizedBox(width: 4),
                Text(
                  request.avgRating!.toStringAsFixed(1),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  ' (${request.totalReviewsCount})',
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
          );
        }
        return SizedBox();
      },
      orElse: () => SizedBox(),
    );
  },
)
```

---

## 🎯 الميزات

### ✅ تم تنفيذها
- [x] إنشاء طلب تقييم (مع قيود: منتج واحد، أسبوعي)
- [x] إضافة تقييم بالنجوم (1-5)
- [x] إضافة تعليق نصي (حد أقصى 5)
- [x] التصويت على فائدة التقييم
- [x] الإبلاغ عن تقييم
- [x] حذف التقييم الخاص
- [x] عرض طلبات التقييم النشطة
- [x] عرض تقييمات منتج
- [x] إحصائيات (متوسط، عدد، progress bar)
- [x] UI جميل ومنظم
- [x] Refresh للبيانات
- [x] Loading states
- [x] Error handling

### 🔜 يمكن إضافتها لاحقاً
- [ ] Sort & Filter للتقييمات
- [ ] Pagination
- [ ] صفحة "تقييماتي"
- [ ] إشعارات عند تقييم منتجك
- [ ] تكامل مع Cloudflare Notifications
- [ ] Admin moderation panel

---

## 🐛 استكشاف الأخطاء

### خطأ في الاتصال بـ Supabase
```dart
// تأكد من تنفيذ جميع ملفات SQL
// تأكد من تفعيل RLS
```

### لا تظهر البيانات
```dart
// استخدم ref.invalidate لإعادة تحميل البيانات
ref.invalidate(activeReviewRequestsProvider);
ref.invalidate(productReviewsProvider);
```

### خطأ في الأذونات
```dart
// تأكد من أن المستخدم مسجل دخول
final userId = Supabase.instance.client.auth.currentUser?.id;
if (userId == null) {
  // User not logged in
}
```

---

## 📝 ملاحظات مهمة

1. **الأذونات**: جميع العمليات تتطلب تسجيل دخول
2. **القيود**: منتج واحد = طلب واحد (UNIQUE constraint)
3. **الحد الأسبوعي**: كل مستخدم = طلب واحد كل 7 أيام
4. **التعليقات**: حد أقصى 5 تعليقات نصية لكل طلب
5. **التقييمات**: غير محدودة (بعد إغلاق التعليقات)
6. **الإحصائيات**: يتم حسابها تلقائياً بـ Triggers

---

## 🎨 التخصيص

يمكنك تعديل الألوان والأحجام مباشرة في الـ Widgets:

```dart
// تغيير لون النجوم
RatingStars(
  rating: 4.5,
  color: Colors.orange, // بدلاً من amber
)

// تغيير حجم البطاقات
// عدل في ReviewRequestCard و ProductReviewCard
```

---

## 📚 المراجع

- Backend SQL: `supabase/migrations/README_REVIEW_SYSTEM.md`
- Business Logic: راجع الدوال في `review_system.dart`
- Examples: الشاشات في نفس الملف

---

✅ **النظام جاهز للاستخدام مباشرة!**

للأسئلة أو المشاكل، راجع الـ Console logs أو استخدم Supabase Dashboard للتحقق من البيانات.
