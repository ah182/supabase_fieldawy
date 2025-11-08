# دليل اختبار النظام المحسّن للبحث
# Enhanced Search System Testing Guide

## 📋 قائمة الاختبارات

### 1. اختبار تسجيل البحث مع التحسين التلقائي

#### الخطوات:
1. افتح أي صفحة بحث في التطبيق
2. ابحث عن منتج بكتابة خاطئة أو ناقصة (مثل: "اموكس" بدلاً من "أموكسيسيلين")
3. تحقق من الـ console logs

#### النتيجة المتوقعة:
```
🔍 Search logged successfully with auto-improvement: اموكس (ID: 123)
```

#### التحقق من قاعدة البيانات:
```sql
SELECT 
    search_term,
    improved_name,
    improvement_score,
    source_table,
    distributor_count
FROM search_tracking
ORDER BY created_at DESC
LIMIT 5;
```

**يجب أن ترى:**
- `search_term`: "اموكس"
- `improved_name`: "أموكسيسيلين 500mg" (أو اسم مشابه)
- `improvement_score`: > 0 (مثل 85، 90، 100)
- `source_table`: "distributor_products" أو "distributor_ocr_products"
- `distributor_count`: عدد الموزعين الذين لديهم هذا المنتج

---

### 2. اختبار جلب الترندات من Dashboard

#### الخطوات:
1. افتح صفحة Dashboard
2. انتقل إلى تبويب "الترندات" أو "Trends"
3. تحقق من الـ console logs

#### النتيجة المتوقعة:
```
🚀 Getting search trends using get_real_search_trends...
✅ Got 10 search trends from get_real_search_trends
```

#### التحقق من البيانات المعروضة:
يجب أن تحتوي كل نتيجة على:
- `keyword`: الاسم المحسّن
- `count`: عدد مرات البحث
- `improvement_score`: درجة التحسين
- `source_table`: مصدر البيانات
- `distributor_count`: عدد الموزعين
- `improved`: true/false

---

### 3. اختبار Fallback في حالة الفشل

#### الخطوات:
1. قم بتعطيل الدالة `get_real_search_trends` مؤقتاً في Supabase
2. افتح Dashboard
3. تحقق من الـ console logs

#### النتيجة المتوقعة:
```
❌ Error getting search trends from get_real_search_trends: ...
🔄 Falling back to fast version...
🚀 Getting search trends - FAST VERSION...
✅ Got X search trends in FAST mode
```

---

### 4. اختبار البحث في جداول مختلفة

#### اختبار 1: منتجات الكتالوج
```
ابحث عن: "أموكسيسيلين"
المتوقع: source_table = "distributor_products"
```

#### اختبار 2: منتجات OCR
```
ابحث عن منتج موجود فقط في OCR
المتوقع: source_table = "distributor_ocr_products"
```

#### اختبار 3: أدوات جراحية
```
ابحث عن: "مشرط"
المتوقع: source_table = "distributor_surgical_tools"
```

#### اختبار 4: مستلزمات بيطرية
```
ابحث عن منتج بيطري
المتوقع: source_table = "vet_supplies"
```

---

### 5. اختبار الترتيب حسب الشعبية

#### الخطوات:
1. ابحث عن منتج موجود عند عدة موزعين
2. تحقق من `distributor_count` في النتيجة

#### النتيجة المتوقعة:
- المنتجات الموجودة عند موزعين أكثر تظهر أولاً
- `distributor_count` يعكس العدد الفعلي للموزعين

---

## 🔍 استعلامات SQL للتحقق

### 1. التحقق من البيانات المحسّنة
```sql
SELECT 
    search_term,
    improved_name,
    improvement_score,
    source_table,
    distributor_count,
    created_at
FROM search_tracking
WHERE improvement_score > 0
ORDER BY created_at DESC
LIMIT 10;
```

### 2. إحصائيات التحسين
```sql
SELECT 
    source_table,
    COUNT(*) as total_searches,
    AVG(improvement_score) as avg_score,
    AVG(distributor_count) as avg_distributors
FROM search_tracking
WHERE improvement_score > 0
GROUP BY source_table
ORDER BY total_searches DESC;
```

### 3. أكثر المنتجات بحثاً (محسّنة)
```sql
SELECT * FROM get_real_search_trends(10, 7);
```

---

## ✅ معايير النجاح

- [ ] تسجيل البحث يعمل بدون أخطاء
- [ ] الأسماء يتم تحسينها تلقائياً
- [ ] `improvement_score` > 0 للنتائج المحسّنة
- [ ] `source_table` يحتوي على اسم الجدول الصحيح
- [ ] `distributor_count` يعكس العدد الفعلي
- [ ] Dashboard يعرض الترندات بشكل صحيح
- [ ] Fallback يعمل في حالة الفشل
- [ ] لا توجد أخطاء في console

---

## 🐛 استكشاف الأخطاء

### خطأ: "function get_real_search_trends does not exist"
**الحل:** قم بتشغيل ملف SQL:
```bash
supabase/enhanced_distributor_search_improvement.sql
```

### خطأ: "column source_table does not exist"
**الحل:** الأعمدة الجديدة لم تُضف بعد. قم بتشغيل:
```sql
ALTER TABLE search_tracking ADD COLUMN source_table TEXT;
ALTER TABLE search_tracking ADD COLUMN distributor_count INTEGER DEFAULT 0;
```

### البيانات لا تظهر في Dashboard
**الحل:** 
1. تحقق من وجود بيانات في `search_tracking`
2. تحقق من صلاحيات الدوال في Supabase
3. تحقق من console logs للأخطاء

---

## 📊 مثال على النتيجة المتوقعة

```json
{
  "keyword": "أموكسيسيلين 500mg",
  "count": 15,
  "unique_users": 5,
  "improvement_score": 95,
  "source_table": "distributor_products",
  "distributor_count": 5,
  "improved": true,
  "trend_direction": "up",
  "growth_percentage": 25.0
}
```

