# 🔧 دليل: دعم المشاهدات للأدوات الجراحية

## ✅ **الحل:**

الأدوات الجراحية موجودة في **جدول منفصل** اسمه `distributor_surgical_tools`، وليس في `distributor_products`.

تم إضافة دعم كامل للمشاهدات لهذا الجدول!

---

## 📊 **بنية الجداول:**

```
📦 distributor_products          → Regular Products
📦 distributor_ocr_products      → OCR Products  
📦 distributor_surgical_tools    → Surgical Tools ✅ (جديد!)
```

---

## 🎯 **ما تم إضافته:**

### **1. SQL - قاعدة البيانات** 💾

#### **عمود views:**
```sql
ALTER TABLE distributor_surgical_tools 
ADD COLUMN views INTEGER DEFAULT 0;
```

#### **Index للأداء:**
```sql
CREATE INDEX idx_distributor_surgical_tools_views 
ON distributor_surgical_tools(views DESC);
```

#### **Function لزيادة المشاهدات:**
```sql
CREATE FUNCTION increment_surgical_tool_views(tool_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE distributor_surgical_tools 
    SET views = COALESCE(views, 0) + 1 
    WHERE id = tool_id;
END;
$$ LANGUAGE plpgsql;
```

---

### **2. الكود - Backend** 🔧

#### **دالة `_incrementProductViews` المحدثة:**

```dart
void _incrementProductViews(
  String productId, 
  {String? distributorId, String? productType}
) {
  if (productType == 'surgical') {
    // أداة جراحية ✅
    Supabase.instance.client.rpc('increment_surgical_tool_views', params: {
      'tool_id': productId,
    });
  } else if (productId.startsWith('ocr_')) {
    // منتج OCR
    // ...
  } else {
    // منتج عادي
    // ...
  }
}
```

---

## 🔍 **كيف يتم التمييز:**

### **الطريقة 1: بواسطة `productType`**
```dart
// في ViewTrackingProductCard
ViewTrackingProductCard(
  product: tool,
  productType: 'surgical', // ✅ المفتاح هنا!
  // ...
)
```

### **الطريقة 2: بواسطة `isSurgicalTool` flag**
```dart
// في showSurgicalToolDialog
_incrementProductViews(
  tool.id, 
  isSurgicalTool: true, // ✅ المفتاح هنا!
);
```

---

## 📋 **سيناريوهات الاستخدام:**

### **سيناريو 1: Regular Product**
```dart
Product: id = "550e8400-..."
productType = "home"
        ↓
increment_product_views(product_id)
        ↓
✅ تحديث distributor_products
```

### **سيناريو 2: OCR Product**
```dart
Product: id = "ocr_ASPIRIN"
productType = "home"
        ↓
يبدأ بـ "ocr_" ✅
        ↓
increment_ocr_product_views(distributor_id, ocr_product_id)
        ↓
✅ تحديث distributor_ocr_products
```

### **سيناريو 3: Surgical Tool** ⭐
```dart
Product: id = "123e4567-..."
productType = "surgical" ✅
        ↓
increment_surgical_tool_views(tool_id)
        ↓
✅ تحديث distributor_surgical_tools
```

---

## 🎯 **التطبيق في الكود:**

### **1. في Surgical Tab (Visibility-based):**

```dart
// home_tabs_content.dart
ViewTrackingProductCard(
  product: tool,
  productType: 'surgical', // ✅ هنا يُحدد النوع
  trackViewOnVisible: false, // لا يحسب عند الظهور
  onTap: () {
    showSurgicalToolDialog(context, tool);
  },
)
```

### **2. في Dialog (Click-based):**

```dart
// product_dialogs.dart
Future<void> showSurgicalToolDialog(BuildContext context, ProductModel tool) {
  // حساب المشاهدة فور فتح الديالوج
  _incrementProductViews(tool.id, isSurgicalTool: true); // ✅
  
  return showDialog(...);
}
```

---

## 🔍 **التحقق من قاعدة البيانات:**

### **1. عرض الأدوات الجراحية الأكثر مشاهدة:**
```sql
SELECT 
    dst.id,
    st.tool_name,
    st.company,
    dst.views
FROM distributor_surgical_tools dst
JOIN surgical_tools st ON dst.surgical_tool_id = st.id
ORDER BY dst.views DESC
LIMIT 10;
```

### **2. إجمالي مشاهدات الأدوات الجراحية:**
```sql
SELECT 
    COUNT(*) as total_tools,
    SUM(views) as total_views,
    AVG(views) as avg_views,
    MAX(views) as max_views
FROM distributor_surgical_tools;
```

### **3. مقارنة بين جميع الأنواع:**
```sql
SELECT 
    'Regular Products' as type,
    COUNT(*) as count,
    SUM(views) as total_views
FROM distributor_products

UNION ALL

SELECT 
    'OCR Products' as type,
    COUNT(*),
    SUM(views)
FROM distributor_ocr_products

UNION ALL

SELECT 
    'Surgical Tools' as type,
    COUNT(*),
    SUM(views)
FROM distributor_surgical_tools;
```

---

## ✅ **الملفات المعدلة:**

1. ✅ `supabase/add_views_to_products.sql`
   - إضافة دعم distributor_surgical_tools

2. ✅ `lib/widgets/product_card.dart`
   - تحديث `_incrementProductViews()`
   - إضافة parameter `productType`

3. ✅ `lib/features/home/presentation/widgets/product_dialogs.dart`
   - تحديث `_incrementProductViews()`
   - إضافة parameter `isSurgicalTool`

---

## 🚀 **خطوات التطبيق:**

### **الخطوة 1: تطبيق SQL المحدث** ⚠️ **إلزامي**
```bash
1. افتح Supabase Dashboard
2. SQL Editor → New Query
3. انسخ محتوى: supabase/add_views_to_products.sql
4. الصق واضغط Run
```

**يتضمن SQL الآن:**
- ✅ Regular products (distributor_products)
- ✅ OCR products (distributor_ocr_products)
- ✅ Surgical tools (distributor_surgical_tools) 🆕

### **الخطوة 2: تشغيل التطبيق**
```bash
flutter run
```

---

## 🧪 **اختبار النظام:**

### **اختبار Surgical Tools:**
```
1. افتح التطبيق
2. اذهب لتاب "الأدوات الجراحية"
3. ❌ اسكرول - المشاهدات لا تزيد (كما هو مطلوب)
4. ✅ اضغط على أداة → يفتح ديالوج
5. ✅ الآن المشاهدة تُحسب!
```

### **التحقق من قاعدة البيانات:**
```sql
-- قبل الضغط
SELECT views FROM distributor_surgical_tools WHERE id = 'xxx';
-- Result: 0

-- بعد الضغط
SELECT views FROM distributor_surgical_tools WHERE id = 'xxx';
-- Result: 1 ✅
```

---

## 📊 **ملخص النظام الكامل:**

| نوع المنتج | الجدول | الـ Function | كيف تُحسب المشاهدة |
|-----------|---------|-------------|-------------------|
| **Regular** | `distributor_products` | `increment_product_views(UUID)` | عند الظهور (Home/Expire/Offers) |
| **OCR** | `distributor_ocr_products` | `increment_ocr_product_views(UUID, TEXT)` | عند الظهور (Home/Expire/Offers) |
| **Surgical** 🆕 | `distributor_surgical_tools` | `increment_surgical_tool_views(UUID)` | عند فتح الديالوج فقط |

---

## 💡 **لماذا جدول منفصل؟**

الأدوات الجراحية لها بنية مختلفة:
```sql
distributor_surgical_tools:
  - id (UUID)
  - distributor_id (UUID)
  - surgical_tool_id (UUID → FK to surgical_tools)
  - description (TEXT)
  - price (NUMERIC)
  - status (TEXT) -- جديد/مستعمل/كسر زيرو
  - views (INTEGER) 🆕
```

**Regular Products:**
```sql
distributor_products:
  - id (UUID)
  - name (TEXT)
  - company (TEXT)
  - package (TEXT)
  - price (NUMERIC)
  - views (INTEGER)
```

**الفرق الرئيسي:**
- Surgical tools → علاقة مع catalog (surgical_tools)
- Regular products → معلومات مباشرة

---

## ⚠️ **ملاحظات مهمة:**

1. **productType = 'surgical':**
   - يُستخدم في ViewTrackingProductCard
   - يُحدد نوع المنتج للتمييز

2. **isSurgicalTool = true:**
   - يُستخدم في showSurgicalToolDialog
   - flag واضح وصريح

3. **لا تُحسب عند الظهور:**
   - `trackViewOnVisible: false`
   - تُحسب فقط عند فتح الديالوج

---

## 🎉 **النتيجة:**

✅ **دعم كامل للأدوات الجراحية**
✅ **3 أنواع من المنتجات (Regular, OCR, Surgical)**
✅ **كل نوع في جدوله الخاص**
✅ **Functions محسنة لكل نوع**
✅ **آمن وسريع ودقيق**

---

**🚀 النظام الآن يدعم جميع أنواع المنتجات بما فيها الأدوات الجراحية!** 🔧
