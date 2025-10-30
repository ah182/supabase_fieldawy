# 🚀 دليل سريع: نظام المشاهدات للمنتجات

## ⚡ **3 خطوات فقط للتشغيل:**

---

### **الخطوة 1: تطبيق SQL** (5 دقائق)

1. افتح [Supabase Dashboard](https://supabase.com/dashboard)
2. اختر مشروعك
3. SQL Editor → New Query
4. افتح الملف: `supabase/add_views_to_products.sql`
5. انسخ **كل** المحتوى
6. الصق في SQL Editor
7. اضغط **Run** (Ctrl+Enter)

**النتيجة المتوقعة:**
```
✅ Success. No rows returned
```

---

### **الخطوة 2: توليد Hive Adapters** (2-3 دقائق)

```bash
# في terminal/cmd
cd D:\fieldawy_store

# إعادة توليد الملفات
flutter packages pub run build_runner build --delete-conflicting-outputs
```

**انتظر حتى تظهر:**
```
[INFO] Succeeded after XXs
```

---

### **الخطوة 3: تشغيل التطبيق**

```bash
flutter run
```

---

## ✅ **كيف أتأكد أن النظام يعمل؟**

### **اختبار سريع (دقيقة واحدة):**

1. **Home Tab:**
   - افتح التطبيق
   - اسكرول لأسفل وشاهد 4-5 منتجات
   - ✅ المشاهدات يجب أن تزيد تلقائياً

2. **Surgical Tools Tab:**
   - اذهب للتاب
   - اسكرول → ❌ المشاهدات لا تزيد
   - اضغط على منتج → يفتح ديالوج
   - ✅ الآن المشاهدة تُحسب

---

## 📊 **كيف يعمل النظام؟**

### **Home / Expire Soon / Offers:**
```
منتج يظهر على الشاشة → ✅ مشاهدة تُحسب تلقائياً
```

### **Surgical Tools:**
```
منتج يظهر على الشاشة → ❌ لا شيء
المستخدم يضغط ويفتح الديالوج → ✅ مشاهدة تُحسب
```

---

## ❌ **حل المشاكل السريع:**

### **مشكلة: Build Runner يفشل**
```bash
flutter clean
flutter pub get
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### **مشكلة: SQL يعطي خطأ**
- تأكد أنك نسخت **كل** محتوى الملف
- تأكد من اتصالك بالإنترنت
- جرب مرة أخرى

### **مشكلة: المشاهدات لا تزيد**
- تأكد من تطبيق SQL ✅
- تأكد من تشغيل Build Runner ✅
- أعد تشغيل التطبيق

---

## 📈 **التحقق من قاعدة البيانات:**

```sql
-- في Supabase SQL Editor
SELECT name, views 
FROM distributor_products 
ORDER BY views DESC 
LIMIT 10;
```

يجب أن ترى المنتجات مع `views > 0`

---

## 💡 **ملاحظات:**

- ✅ المشاهدات تُحسب **مرة واحدة فقط** لكل منتج في الجلسة
- ✅ عند إغلاق التطبيق، يمكن حسابها مرة أخرى في الجلسة التالية
- ✅ هذا سلوك طبيعي ومشابه لـ YouTube, Instagram

---

## 📖 **للمزيد من التفاصيل:**

راجع الملف الكامل: `PRODUCT_VIEWS_SYSTEM_GUIDE.md`

---

**🎉 كل شيء جاهز! ابدأ الاستخدام الآن!**
