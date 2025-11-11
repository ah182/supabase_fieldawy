# إصلاح: صورة المنتج في Dialog التعليق ✅

## المشكلة 🐛

عند فتح dialog التعليق بعد اختيار المنتج، كانت تظهر placeholder بدلاً من صورة المنتج الفعلية.

### السبب:
- `AddFromCatalogScreen` كان يرجع فقط `product_id` و `product_type`
- `AddProductOcrScreen` كان يرجع فقط `product_id` و `product_type`
- لم يتم إرجاع `product_name` أو `product_image`

---

## الحل ✅

تم تحديث كلا الملفين لإرجاع معلومات كاملة عن المنتج.

---

## التغييرات التي تمت 📝

### 1. AddFromCatalogScreen

**الملف**: `lib/features/products/presentation/screens/add_from_catalog_screen.dart`

#### قبل التعديل ❌:

```dart
Navigator.pop(context, {
  'product_id': productId,
  'product_type': productType,
});
```

#### بعد التعديل ✅:

```dart
// البحث عن معلومات المنتج (الاسم والصورة)
String? productName;
String? productImage;

final provider = _tabController?.index == 0 ? productsProvider : ocrProductsProvider;
final asyncValue = ref.read(provider);

asyncValue.whenData((products) {
  final product = products.firstWhere(
    (p) => p.id == productId,
    orElse: () => products.first,
  );
  productName = product.name;
  productImage = product.imageUrl;
});

Navigator.pop(context, {
  'product_id': productId,
  'product_type': productType,
  'product_name': productName ?? 'منتج',
  'product_image': productImage ?? '',
});
```

**ما تم:**
- قراءة قائمة المنتجات من Provider (productsProvider أو ocrProductsProvider)
- البحث عن المنتج المحدد باستخدام `firstWhere`
- استخراج الاسم (`product.name`) والصورة (`product.imageUrl`)
- إرجاع البيانات الكاملة

---

### 2. AddProductOcrScreen

**الملف**: `lib/features/products/presentation/screens/add_product_ocr_screen.dart`

#### قبل التعديل ❌:

```dart
Navigator.pop(context, {
  'product_id': ocrProductId,
  'product_type': 'ocr_product',
});
```

#### بعد التعديل ✅:

```dart
Navigator.pop(context, {
  'product_id': ocrProductId,
  'product_type': 'ocr_product',
  'product_name': name,
  'product_image': finalUrl,
});
```

**ما تم:**
- إضافة `product_name` (من `name` المتغير الموجود أصلاً)
- إضافة `product_image` (من `finalUrl` الصورة المرفوعة على Cloudinary)

---

## النتيجة 🎯

الآن عند اختيار منتج (من الكتالوج أو من المعرض):

### البيانات المرجعة:

```dart
{
  'product_id': 'xxx',
  'product_type': 'product' أو 'ocr_product',
  'product_name': 'اسم المنتج',
  'product_image': 'https://cloudinary.com/...',
}
```

### عرض Dialog التعليق:

```dart
_showCommentDialog(context, ref, selectedProduct);
```

الآن `selectedProduct` يحتوي على:
- ✅ `product_id`
- ✅ `product_type`
- ✅ `product_name` ← **جديد**
- ✅ `product_image` ← **جديد**

---

## Dialog التعليق 💬

### الكود:

```dart
// صورة المنتج
Container(
  width: 120,
  height: 120,
  child: CachedNetworkImage(
    imageUrl: selectedProduct['product_image'], // ✅ الآن يعمل!
    fit: BoxFit.cover,
    ...
  ),
),

// اسم المنتج
Text(
  selectedProduct['product_name'], // ✅ الآن يعمل!
  style: titleMedium,
),
```

---

## الاختبار ✅

### خطوات الاختبار:

1. ✅ افتح صفحة التقييمات
2. ✅ اضغط "إضافة طلب تقييم"
3. ✅ اختر "من الكتالوج"
4. ✅ اختر منتج
5. ✅ **تحقق من ظهور صورة المنتج الفعلية** (ليس placeholder)
6. ✅ **تحقق من ظهور اسم المنتج الصحيح**
7. ✅ اكتب تعليق واضغط "إرسال الطلب"

8. ✅ كرر مع "من المعرض":
   - التقط صورة أو اختر من المعرض
   - املأ بيانات المنتج
   - احفظ
   - **تحقق من ظهور الصورة المرفوعة في dialog التعليق**

---

## الملفات المعدلة 📁

| الملف | التغيير |
|------|---------|
| `lib/features/products/presentation/screens/add_from_catalog_screen.dart` | ✅ إضافة product_name و product_image عند الإرجاع |
| `lib/features/products/presentation/screens/add_product_ocr_screen.dart` | ✅ إضافة product_name و product_image عند الإرجاع |

**المجموع**: 2 ملف محدث

---

## قبل وبعد 📸

### قبل التعديل ❌:
```
Dialog يفتح مع:
🔲 Placeholder (أيقونة دواء رمادية)
📝 "منتج" (نص افتراضي)
```

### بعد التعديل ✅:
```
Dialog يفتح مع:
🖼️ صورة المنتج الفعلية
📝 اسم المنتج الصحيح
```

---

## ملاحظات 📌

### AddFromCatalogScreen:
- يستخدم `asyncValue.whenData()` للحصول على القائمة
- يستخدم `firstWhere()` للبحث عن المنتج بالـ ID
- fallback: `'منتج'` للاسم، `''` للصورة

### AddProductOcrScreen:
- المتغيرات `name` و `finalUrl` موجودة بالفعل
- تم إضافتها مباشرة للبيانات المرجعة
- `finalUrl` هو رابط Cloudinary بعد رفع الصورة

---

## الفائدة 🎯

1. **تجربة مستخدم أفضل**: رؤية المنتج قبل كتابة التعليق
2. **معلومات دقيقة**: الاسم والصورة الصحيحة تساعد المستخدم
3. **تدفق منطقي**: اختيار → رؤية → تعليق
4. **لا placeholder**: صور حقيقية فقط! 🖼️

---

تم إصلاح المشكلة! الآن صورة المنتج تظهر بشكل صحيح في dialog التعليق. ✨
