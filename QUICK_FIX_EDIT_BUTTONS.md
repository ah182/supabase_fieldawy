# 🚀 إصلاح سريع - إضافة Edit Buttons

## المشكلة:
Edit buttons مش ظاهرة → بيظهر "Coming Soon"

## الحل السريع (خطوتين):

---

## ✅ الخطوة 1: تطبيق SQL Policies (ضروري!)

افتح **Supabase SQL Editor** وشغّل الكود ده:

```sql
-- Books
DROP POLICY IF EXISTS "admin_update_all_books" ON vet_books;
CREATE POLICY "admin_update_all_books" ON vet_books FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- Courses
DROP POLICY IF EXISTS "admin_update_all_courses" ON vet_courses;
CREATE POLICY "admin_update_all_courses" ON vet_courses FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- Jobs
DROP POLICY IF EXISTS "admin_update_all_jobs" ON job_offers;
CREATE POLICY "admin_update_all_jobs" ON job_offers FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- Products (Catalog)
DROP POLICY IF EXISTS "admin_update_all_products" ON products;
CREATE POLICY "admin_update_all_products" ON products FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin_delete_all_products" ON products;
CREATE POLICY "admin_delete_all_products" ON products FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- Distributor Products
DROP POLICY IF EXISTS "admin_update_all_distributor_products" ON distributor_products;
CREATE POLICY "admin_update_all_distributor_products" ON distributor_products FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "admin_delete_all_distributor_products" ON distributor_products;
CREATE POLICY "admin_delete_all_distributor_products" ON distributor_products FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- Vet Supplies
DROP POLICY IF EXISTS "admin_update_all_vet_supplies" ON vet_supplies;
CREATE POLICY "admin_update_all_vet_supplies" ON vet_supplies FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- Offers
DROP POLICY IF EXISTS "admin_update_all_offers" ON offers;
CREATE POLICY "admin_update_all_offers" ON offers FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- Surgical Tools
DROP POLICY IF EXISTS "admin_update_all_surgical_tools" ON distributor_surgical_tools;
CREATE POLICY "admin_update_all_surgical_tools" ON distributor_surgical_tools FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- OCR Products
DROP POLICY IF EXISTS "admin_update_all_ocr_products" ON distributor_ocr_products;
CREATE POLICY "admin_update_all_ocr_products" ON distributor_ocr_products FOR UPDATE TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- التحقق من نجاح العملية
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE policyname LIKE 'admin_update%' OR policyname LIKE 'admin_delete%'
ORDER BY tablename;
```

---

## ✅ الخطوة 2: إضافة Edit Buttons في الكود

### طريقة سهلة جداً:

#### أ) افتح الملف:
`lib/features/admin_dashboard/presentation/screens/product_management_screen.dart`

#### ب) استخدم البحث (Ctrl+F) وابحث عن الأسطر دي:

---

### 🔹 Books Tab:

**ابحث عن:**
```dart
IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(book))
```

**غيرها لـ:**
```dart
IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit', onPressed: () => _showEditDialog(book)),
IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(book))
```

---

### 🔹 Courses Tab:

**ابحث عن:**
```dart
IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(course))
```

**غيرها لـ:**
```dart
IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit', onPressed: () => _showEditDialog(course)),
IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(course))
```

---

### 🔹 Jobs Tab:

**ابحث عن:**
```dart
IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(job))
```

**غيرها لـ:**
```dart
IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit', onPressed: () => _showEditDialog(job)),
IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(job))
```

---

### 🔹 Catalog Products Tab:

**ابحث عن:**
```dart
onPressed: () => _showCatalogDetails(product)
```

**غيرها لـ:**
```dart
onPressed: () => _showCatalogDetails(product)),
IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit', onPressed: () => _showCatalogEditDialog(product)),
IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmCatalogDelete(product)
```

---

### 🔹 Distributor Products Tab:

**ابحث عن:**
```dart
onPressed: () => _showDistributorDetails(product)
```

**غيرها لـ:**
```dart
onPressed: () => _showDistributorDetails(product)),
IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit', onPressed: () => _showDistributorEditDialog(product)),
IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDistributorDelete(product)
```

---

## ✅ الخطوة 3: إضافة Edit Dialogs

بعد كل `_showDetails` method، أضف الـ `_showEditDialog` و `_confirmDelete` من الملفات التالية:

- **Books**: `ADD_EDIT_TO_BOOKS_COURSES_JOBS.md` → الخطوة 3
- **Courses**: نفس الملف → الخطوة 4
- **Jobs**: نفس الملف → الخطوة 5
- **Catalog Products**: `ADD_EDIT_DELETE_TO_CATALOG_DISTRIBUTOR_PRODUCTS.md` → الخطوة 2
- **Distributor Products**: نفس الملف → الخطوة 3

---

## 🔥 الطريقة الأسرع (إذا كان الكود صعب):

### بدلاً من التعديل اليدوي، اعمل الآتي:

1. **اقفل Android Studio / VS Code**
2. **احذف** الملف: `lib/features/admin_dashboard/presentation/screens/product_management_screen.dart`
3. **أعد فتح** الـ IDE
4. **أنشئ الملف من جديد** بالكود الكامل من الملفات التوثيقية

---

## 🧪 الاختبار:

بعد الخطوات دي:

1. سجّل **خروج** من Admin Dashboard
2. سجّل **دخول** مرة تانية
3. افتح أي tab
4. هتلاقي 3 أزرار:
   - 👁️ View (أزرق فاتح)
   - ✏️ Edit (أزرق)
   - 🗑️ Delete (أحمر)

---

## ⚠️ إذا ما زالت المشكلة موجودة:

شغّل هذا الـ Query في Supabase للتأكد:

```sql
-- التحقق من admin user
SELECT id, email, role, account_status 
FROM users 
WHERE email = 'admin@fieldawy.com';

-- لازم يكون:
-- role = 'admin'
-- account_status = 'approved'
```

إذا مش صح، شغّل:
```sql
UPDATE users 
SET role = 'admin', account_status = 'approved' 
WHERE email = 'admin@fieldawy.com';
```

---

## 📊 النتيجة المتوقعة:

كل Tab هيبقى فيه:
- ✅ View button (أزرق فاتح) 
- ✅ Edit button (أزرق)
- ✅ Delete button (أحمر)

وكل واحد هيفتح Dialog للتعديل أو التأكيد على الحذف!

---

**اتبع الخطوة 1 الأول (SQL)، بعدين الخطوة 2 (الـ Buttons)** 🚀
