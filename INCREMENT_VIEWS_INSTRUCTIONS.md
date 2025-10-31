# 📈 تعليمات إضافة زيادة المشاهدات للوظائف والمستلزمات

## 🎯 **المطلوب تنفيذه:**

### **1️⃣ تحديث provider الوظائف:**

**في `lib/features/jobs/application/job_offers_provider.dart`** - أضف هذه الدالة داخل كلاس `JobOffersNotifier`:

```dart
// ✅ إضافة دالة زيادة المشاهدات
Future<void> incrementViews(String jobId) async {
  await _repository.incrementJobViews(jobId);
  // تحديث المشاهدات في الحالة المحلية
  state.whenData((jobs) {
    final updatedJobs = jobs.map((job) {
      if (job.id == jobId) {
        return JobOffer(
          id: job.id,
          userId: job.userId,
          title: job.title,
          description: job.description,
          phone: job.phone,
          status: job.status,
          viewsCount: job.viewsCount + 1, // زيادة المشاهدات
          createdAt: job.createdAt,
          updatedAt: job.updatedAt,
          userName: job.userName,
        );
      }
      return job;
    }).toList();
    state = AsyncValue.data(updatedJobs);
  });
}
```

**وأضف نفس الدالة في كلاس `MyJobOffersNotifier` أيضاً.**

---

### **2️⃣ تحديث شاشة الوظائف:**

**في `lib/features/jobs/presentation/screens/job_offers_screen.dart`** - في دالة `_showJobDetailsDialog` (السطر حوالي 398):

```dart
void _showJobDetailsDialog(BuildContext context, JobOffer job) {
  // ✅ زيادة المشاهدات عند فتح التفاصيل
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ref = ProviderScope.containerOf(context).read;
    ref(allJobOffersNotifierProvider.notifier).incrementViews(job.id);
  });
  
  showDialog(
    context: context,
    builder: (context) => _JobDetailsDialog(job: job),
  );
}
```

---

### **3️⃣ تحديث كارت الوظيفة:**

**في نفس الملف** - في كلاس `_JobOfferCard` (السطر حوالي 604) - أضف هذا في `onTap`:

```dart
child: InkWell(
  onTap: () {
    // ✅ زيادة المشاهدات عند النقر على الكارت
    if (onTap != null) {
      onTap!();
    }
  },
  borderRadius: BorderRadius.circular(12),
  // باقي الكود...
```

---

### **4️⃣ إنشاء SQL Function للوظائف:**

**في Supabase SQL Editor** - تشغيل هذا الـ script:

```sql
-- دالة زيادة مشاهدات الوظائف
CREATE OR REPLACE FUNCTION increment_job_views(p_job_id TEXT)
RETURNS void AS $$
BEGIN
  UPDATE job_offers 
  SET views_count = COALESCE(views_count, 0) + 1,
      updated_at = NOW()
  WHERE id = p_job_id;
END;
$$ LANGUAGE plpgsql;

-- دالة زيادة مشاهدات المستلزمات (إذا لم تكن موجودة)
CREATE OR REPLACE FUNCTION increment_vet_supply_views(p_supply_id TEXT)
RETURNS void AS $$
BEGIN
  UPDATE vet_supplies 
  SET views_count = COALESCE(views_count, 0) + 1,
      updated_at = NOW()
  WHERE id = p_supply_id;
END;
$$ LANGUAGE plpgsql;

-- التأكد من إنجاز الإعداد
SELECT 'Views increment functions created successfully!' as status;
```

---

## 🧪 **كيفية الاختبار:**

### **للوظائف:**
1. افتح صفحة الوظائف
2. اضغط على أي وظيفة لفتح التفاصيل
3. ستزيد المشاهدات تلقائياً
4. أغلق وأعد فتح الوظيفة → ستجد المشاهدات زادت

### **للمستلزمات:**
1. افتح صفحة المستلزمات البيطرية
2. اضغط على أي مستلزم
3. ستزيد المشاهدات تلقائياً (النظام موجود بالفعل)

---

## 📊 **النتيجة المتوقعة:**

### **بعد التحديث:**
- ✅ **الوظائف**: زيادة المشاهدات عند فتح التفاصيل
- ✅ **المستلزمات**: زيادة المشاهدات عند الضغط (يعمل بالفعل)
- ✅ **حماية**: لا يزيد المشاهدات عند تحديث قاعدة البيانات
- ✅ **مزامنة**: المشاهدات تحدث فوراً في الواجهة

---

## 🔧 **ملاحظات مهمة:**

1. **المستلزمات البيطرية** تعمل بالفعل ✅
2. **الوظائف** تحتاج للتحديثات المذكورة أعلاه
3. **الدوال SQL** موجودة في repository لكن تحتاج للـ SQL functions
4. **التحديث المحلي** يجعل الواجهة تتفاعل فوراً

---

هل تريد مني تطبيق هذه التحديثات أم تفضل تطبيقها بنفسك؟