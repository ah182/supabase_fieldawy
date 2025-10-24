# 📍 دليل العثور على الميزات - Admin Dashboard

## 🎯 كيف تصل للـ Dashboard؟

افتح المتصفح واذهب إلى:
```
http://localhost:61228/admin/dashboard
```

---

## 📊 التقسيمات الرئيسية (4 Tabs في القائمة الجانبية)

### 1️⃣ **Dashboard** (Tab الأول)
**الميزات الموجودة:**
- ✅ **Stats Cards**: إحصائيات (Users, Doctors, Distributors, Companies, Products)
- ✅ **Pending Approvals**: الموافقات المعلقة (موافقة/رفض سريعة)
- ✅ **Quick Actions**: لوحة الإجراءات السريعة (8 اختصارات)
- ✅ **Recent Activity**: سجل النشاطات الأخيرة
- ✅ **Notification Manager**: إرسال إشعارات Push
- ✅ **Backup & Restore**: النسخ الاحتياطي والاستعادة

**كيف تستخدمها:**
- اضغط على "Dashboard" في القائمة الجانبية
- scroll لأسفل لرؤية جميع الميزات

---

### 2️⃣ **Users Management** (Tab الثاني)
**الميزات الموجودة:**
- ✅ **3 Tabs**: Doctors, Distributors, Companies
- ✅ **Export/Import Toolbar** (جديد! ✨):
  - زر Excel (أخضر) - تصدير لـ Excel
  - زر CSV (أزرق) - تصدير لـ CSV
  - زر PDF (أحمر) - تصدير لـ PDF
  - زر Import CSV (بنفسجي) - استيراد من CSV
  - زر Refresh - تحديث البيانات
- ✅ **PaginatedDataTable**: جدول بيانات مع صفحات
- ✅ **Actions**: View Details, Edit Status, Delete User

**كيف تستخدمها:**
1. اضغط على "Users" في القائمة الجانبية
2. اختر Tab (Doctors / Distributors / Companies)
3. ستجد الـ toolbar فوق الجدول مباشرة
4. اضغط على أي زر Export لتحميل البيانات
5. اضغط على Import CSV لرفع ملف

---

### 3️⃣ **Products Management** (Tab الثالث)
**الميزات الموجودة:**
- ✅ **9 Tabs**: 
  - Catalog Products
  - Distributor Products
  - Books
  - Courses
  - Jobs
  - Surgical Tools
  - Vet Supplies
  - Offers
  - OCR Products
- ✅ **View Details**: معاينة تفاصيل كل منتج
- ✅ **Delete**: حذف المنتجات

**ملاحظة:** 
- Export/Import buttons يمكن إضافتها لاحقاً (غير موجودة حالياً)

---

### 4️⃣ **Analytics & Insights** (Tab الرابع) ⭐ **هنا كل التحليلات!**
**الميزات الموجودة:**
- ✅ **User Growth Analytics**: رسوم بيانية للنمو (Line Chart + Bar Chart)
- ✅ **Top Performers**: أفضل الأداء (منتجات ومستخدمين)
- ✅ **Advanced Search**: بحث متقدم شامل
- ✅ **Geographic Distribution**: التوزيع الجغرافي (أول 3 محافظات)
- ✅ **System Health**: صحة النظام (Database, Products, Logs)
- ✅ **Offers Tracker**: متتبع العروض (Active / Ended)
- ✅ **Performance Monitor**: مراقب الأداء (Response Time, API Calls)
- ✅ **Error Logs Viewer**: عارض سجلات الأخطاء

**كيف تستخدمها:**
1. اضغط على "Analytics" في القائمة الجانبية (آخر tab)
2. scroll لأسفل لرؤية جميع الـ widgets
3. كل widget له وظيفة مستقلة

---

## 🎨 الميزات المخفية التي ربما لم تلاحظها:

### 📤 Export/Import (موجود الآن!)
**الموقع:** Users Management → فوق كل جدول
**الأزرار:**
- **Excel** (أخضر): تصدير لـ .xlsx
- **CSV** (أزرق): تصدير لـ .csv
- **PDF** (أحمر): تصدير لـ PDF مع جداول
- **Import CSV** (بنفسجي): استيراد بيانات من CSV
- **Refresh** (أيقونة): تحديث البيانات

**كيفية الاستخدام:**
```
1. اذهب لـ Users Management
2. اختر tab (Doctors مثلاً)
3. اضغط على "Excel" أو "CSV" أو "PDF"
4. سيتم تحميل الملف تلقائياً
```

---

### 🔔 Push Notifications Manager
**الموقع:** Dashboard الرئيسي → scroll لأسفل
**الوظائف:**
- إرسال لكل المستخدمين
- إرسال حسب الدور (Doctors/Distributors/Companies)
- إرسال حسب المحافظة
- جدولة الإشعارات
- معاينة قبل الإرسال

---

### 💾 Backup & Restore
**الموقع:** Dashboard الرئيسي → في الأسفل
**الوظائف:**
- **Create Backup**: نسخ احتياطي لكل البيانات (9 جداول)
- **Restore Backup**: استعادة من نسخة احتياطية سابقة

---

### 📊 Pending Approvals
**الموقع:** Dashboard الرئيسي → أعلى الصفحة (يسار)
**الوظائف:**
- عرض طلبات التسجيل المعلقة
- موافقة سريعة (Approve)
- رفض سريع (Reject)

---

### ⚡ Quick Actions
**الموقع:** Dashboard الرئيسي → أعلى الصفحة (يمين)
**الاختصارات:**
- Add Product
- Add Offer
- View Users
- View Products
- View Analytics
- View Books
- View Courses
- View Jobs

---

### 📈 User Growth Analytics
**الموقع:** Analytics Tab → أول widget
**الوظائف:**
- رسم بياني Line Chart
- رسم بياني Bar Chart
- بيانات شهرية

---

### 🔍 Advanced Search
**الموقع:** Analytics Tab → بعد Top Performers
**الوظائف:**
- بحث شامل في المستخدمين
- بحث شامل في المنتجات
- نتائج فورية

---

### 🗺️ Geographic Distribution
**الموقع:** Analytics Tab → نصف الشاشة (يسار)
**الوظائف:**
- توزيع المستخدمين حسب المحافظة
- أول 3 محافظات بميداليات
- Progress bars ملونة

---

### 🏥 System Health
**الموقع:** Analytics Tab → نصف الشاشة (يمين)
**الوظائف:**
- حالة Database
- حالة Products
- حالة Activity Logs
- التنبيهات النشطة

---

### 🎁 Offers Tracker
**الموقع:** Analytics Tab
**الوظائف:**
- Tab للعروض النشطة (Active)
- Tab للعروض المنتهية (Ended)
- تنبيه للعروض القريبة من الانتهاء

---

### ⚡ Performance Monitor
**الموقع:** Analytics Tab → الصف الأخير (يسار)
**الوظائف:**
- متوسط وقت الاستجابة
- عدد API calls
- معدل النجاح
- أبطأ الاستعلامات

---

### 🐛 Error Logs Viewer
**الموقع:** Analytics Tab → الصف الأخير (يمين)
**الوظائف:**
- عرض جميع الأخطاء
- عدد المستخدمين المتأثرين
- Stack traces كاملة
- تفاصيل كل خطأ

---

## 🚫 الميزات غير الموجودة (لم يتم تنفيذها):

❌ **Bulk Operations** (تحديد متعدد + موافقة/رفض/حذف جماعي)
- لم يتم إضافتها لتبسيط الـ UI
- يمكن إضافتها لاحقاً إذا لزم الأمر

❌ **Export في Products Management**
- موجود فقط في Users Management
- يمكن إضافته بسهولة بنفس الطريقة

---

## 🎯 الملخص السريع:

| الميزة | الموقع | الحالة |
|--------|--------|--------|
| Stats Cards | Dashboard → أعلى | ✅ موجود |
| Pending Approvals | Dashboard → يسار | ✅ موجود |
| Quick Actions | Dashboard → يمين | ✅ موجود |
| Recent Activity | Dashboard → منتصف | ✅ موجود |
| Notifications | Dashboard → أسفل | ✅ موجود |
| Backup & Restore | Dashboard → أسفل | ✅ موجود |
| Export/Import | Users Management → Toolbar | ✅ موجود (جديد!) |
| User Growth | Analytics Tab | ✅ موجود |
| Top Performers | Analytics Tab | ✅ موجود |
| Advanced Search | Analytics Tab | ✅ موجود |
| Geographic Dist. | Analytics Tab | ✅ موجود |
| System Health | Analytics Tab | ✅ موجود |
| Offers Tracker | Analytics Tab | ✅ موجود |
| Performance | Analytics Tab | ✅ موجود |
| Error Logs | Analytics Tab | ✅ موجود |
| Bulk Operations | - | ❌ غير موجود |

---

## 🔧 كيفية التشغيل:

```bash
# في PowerShell
cd D:\fieldawy_store
flutter run -d chrome --web-port=61228
```

ثم افتح المتصفح:
```
http://localhost:61228/admin/dashboard
```

---

## 📝 ملاحظات:

1. **Analytics Tab** يحتوي على معظم الميزات المتقدمة
2. **Export/Import** تم إضافته اليوم في Users Management فقط
3. كل الـ widgets في ملفات منفصلة في مجلد `widgets/`
4. كل الـ services في مجلد `core/services/`
5. SQL scripts في مجلد `supabase/`

---

**تم إنشاء هذا الدليل:** اليوم
**الإصدار:** 1.0
**الحالة:** ✅ جميع الميزات المذكورة تعمل بنجاح
