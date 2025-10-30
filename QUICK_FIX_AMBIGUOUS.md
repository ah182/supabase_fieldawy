# ⚡ حل سريع: column reference is ambiguous

## ❌ **الخطأ الجديد:**
```
PostgrestException(message: column reference "product_id" is ambiguous, code: 42702)
```

---

## 🔍 **السبب:**

**المشكلة:**
```sql
-- Function القديمة
CREATE FUNCTION increment_product_views(product_id TEXT)  -- اسم parameter
...
WHERE id::TEXT = product_id;  -- ❌ product_id غامض!
```

**لماذا "غامض"؟**
- قد يكون `product_id` = parameter name
- أو قد يكون `product_id` = column في جدول آخر مرتبط
- PostgreSQL لا يعرف أيهما تقصد!

---

## ✅ **الحل:**

**استخدام prefix مثل `p_` للـ parameters:**

```sql
-- ❌ قبل:
CREATE FUNCTION increment_product_views(product_id TEXT)
WHERE id::TEXT = product_id;  -- غامض

-- ✅ بعد:
CREATE FUNCTION increment_product_views(p_product_id TEXT)
WHERE id::TEXT = p_product_id;  -- واضح!
```

---

## 🚀 **خطوات التطبيق:**

### **الخطوة 1: تطبيق SQL المُحدث** ⚠️

```bash
1. افتح Supabase Dashboard
2. SQL Editor → New Query
3. افتح: supabase/fix_views_functions_text_id.sql
4. انسخ كل المحتوى (المُحدث!)
5. الصق في SQL Editor
6. اضغط Run
```

**النتيجة المتوقعة:**
```
✅ Success. No rows returned
```

---

### **الخطوة 2: اختبر في SQL**

```sql
-- اختبر بـ ID حقيقي
SELECT increment_product_views('733');

-- تحقق
SELECT id, name, views 
FROM distributor_products 
WHERE id::TEXT = '733';
```

**يجب أن ترى views = 1 ✅**

---

### **الخطوة 3: اختبر في Flutter**

```bash
flutter run
```

**افتح Home Tab → اسكرول**

**Console يجب أن يعرض:**
```
🔵 Incrementing views for product: 733
✅ Regular product views incremented successfully
```

**لا أخطاء! ✅**

---

## 🔧 **التغييرات في SQL:**

### **Functions الثلاثة:**

1. ✅ `increment_product_views(p_product_id TEXT)`
2. ✅ `increment_ocr_product_views(p_distributor_id TEXT, p_ocr_product_id TEXT)`
3. ✅ `increment_surgical_tool_views(p_tool_id TEXT)`

**كل الـ parameters الآن تبدأ بـ `p_` للوضوح!**

---

## 📋 **Checklist:**

- [ ] ✅ حذفت Functions القديمة
- [ ] ✅ طبقت SQL الجديد بأسماء parameters واضحة
- [ ] ✅ اختبرت يدوياً: `SELECT increment_product_views('733')`
- [ ] ✅ شغلت `flutter run`
- [ ] ✅ رأيت: "✅ Regular product views incremented"
- [ ] ✅ views زادت في قاعدة البيانات
- [ ] ✅ العداد ظهر في UI

---

## 🎯 **النتيجة:**

```
❌ قبل:
column reference "product_id" is ambiguous

✅ بعد:
Regular product views incremented successfully for ID: 733
```

---

**🚀 الآن طبق SQL المُحدث وكل شيء سيعمل!** ✨

**ملاحظة:** ملف `fix_views_functions_text_id.sql` تم تحديثه تلقائياً - فقط أعد تطبيقه!
