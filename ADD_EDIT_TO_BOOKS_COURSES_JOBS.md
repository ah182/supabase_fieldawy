# إضافة Edit لـ Books, Courses, Jobs

## ✅ تم بالفعل:
1. ✅ إضافة `adminUpdateBook()` في `books_repository.dart`
2. ✅ إضافة `adminUpdateCourse()` في `courses_repository.dart`  
3. ✅ إضافة `adminUpdateJobOffer()` - انظر الخطوة 1 أدناه

---

## الخطوة 1️⃣: إضافة Update Method لـ Jobs

افتح `lib/features/jobs/data/job_offers_repository.dart`

أضف هذا الكود **قبل آخر `}`:**

```dart
  /// Admin: Update any job offer
  Future<bool> adminUpdateJobOffer({
    required String jobId,
    required String title,
    required String phone,
    required String description,
    required String status,
  }) async {
    try {
      await _supabase
          .from('job_offers')
          .update({
            'title': title,
            'phone': phone,
            'description': description,
            'status': status,
          })
          .eq('id', jobId);
      
      return true;
    } catch (e) {
      throw Exception('Failed to update job offer: $e');
    }
  }
```

---

## الخطوة 2️⃣: إضافة Edit Button لـ Books

في `product_management_screen.dart`، ابحث عن:

```dart
DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
  IconButton(icon: const Icon(Icons.visibility, size: 20), tooltip: 'View', onPressed: () => _showDetails(book)),
  IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(book))
]))
```

**استبدله بـ:**

```dart
DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
  IconButton(icon: const Icon(Icons.visibility, size: 20), tooltip: 'View', onPressed: () => _showDetails(book)),
  IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit', onPressed: () => _showEditDialog(book)),
  IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(book))
]))
```

---

## الخطوة 3️⃣: إضافة Edit Dialog لـ Books

في `_BooksDataSource` class، أضف هذا الكود بعد `_showDetails`:

```dart
  void _showEditDialog(Book book) {
    final nameController = TextEditingController(text: book.name);
    final authorController = TextEditingController(text: book.author);
    final priceController = TextEditingController(text: book.price.toString());
    final phoneController = TextEditingController(text: book.phone);
    final descController = TextEditingController(text: book.description);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Book'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: authorController, decoration: const InputDecoration(labelText: 'Author')),
                const SizedBox(height: 8),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price (EGP)'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 8),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final author = authorController.text.trim();
              final priceText = priceController.text.trim();
              final phone = phoneController.text.trim();
              final desc = descController.text.trim();
              
              if (name.isEmpty || author.isEmpty || priceText.isEmpty || phone.isEmpty || desc.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                return;
              }
              
              final price = double.tryParse(priceText);
              if (price == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid price')));
                return;
              }
              
              try {
                Navigator.pop(context);
                final success = await ref.read(booksRepositoryProvider).adminUpdateBook(
                  bookId: book.id,
                  name: name,
                  author: author,
                  price: price,
                  phone: phone,
                  description: desc,
                );
                
                if (success) {
                  ref.invalidate(adminAllBooksProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Updated successfully'), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Update failed'), backgroundColor: Colors.red));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
```

---

## الخطوة 4️⃣: نفس الشيء لـ Courses

**Edit Button:**
```dart
IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit', onPressed: () => _showEditDialog(course)),
```

**Edit Dialog:**
```dart
  void _showEditDialog(Course course) {
    final titleController = TextEditingController(text: course.title);
    final priceController = TextEditingController(text: course.price.toString());
    final phoneController = TextEditingController(text: course.phone);
    final descController = TextEditingController(text: course.description);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Course'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 8),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price (EGP)'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 8),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final priceText = priceController.text.trim();
              final phone = phoneController.text.trim();
              final desc = descController.text.trim();
              
              if (title.isEmpty || priceText.isEmpty || phone.isEmpty || desc.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                return;
              }
              
              final price = double.tryParse(priceText);
              if (price == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid price')));
                return;
              }
              
              try {
                Navigator.pop(context);
                final success = await ref.read(coursesRepositoryProvider).adminUpdateCourse(
                  courseId: course.id,
                  title: title,
                  price: price,
                  phone: phone,
                  description: desc,
                );
                
                if (success) {
                  ref.invalidate(adminAllCoursesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Updated successfully'), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Update failed'), backgroundColor: Colors.red));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
```

---

## الخطوة 5️⃣: نفس الشيء لـ Jobs

**Edit Button:**
```dart
IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit', onPressed: () => _showEditDialog(job)),
```

**Edit Dialog:**
```dart
  void _showEditDialog(JobOffer job) {
    final titleController = TextEditingController(text: job.title);
    final phoneController = TextEditingController(text: job.phone);
    final descController = TextEditingController(text: job.description);
    String selectedStatus = job.status;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Job Offer'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title'), maxLines: 2),
                  const SizedBox(height: 8),
                  TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
                  const SizedBox(height: 8),
                  TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 4),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Open')),
                      DropdownMenuItem(value: 'closed', child: Text('Closed')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedStatus = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final phone = phoneController.text.trim();
                final desc = descController.text.trim();
                
                if (title.isEmpty || phone.isEmpty || desc.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                  return;
                }
                
                try {
                  Navigator.pop(context);
                  final success = await ref.read(jobOffersRepositoryProvider).adminUpdateJobOffer(
                    jobId: job.id,
                    title: title,
                    phone: phone,
                    description: desc,
                    status: selectedStatus,
                  );
                  
                  if (success) {
                    ref.invalidate(adminAllJobOffersProvider);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Updated successfully'), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Update failed'), backgroundColor: Colors.red));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
```

---

## الخطوة 6️⃣: إضافة RLS Policies في Supabase

افتح `supabase/FIX_ADMIN_EDIT_DELETE_POLICIES.sql` وأضف هذا في النهاية:

```sql
-- Admin can update books
DROP POLICY IF EXISTS "admin_update_all_books" ON vet_books;
CREATE POLICY "admin_update_all_books"
ON vet_books
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Admin can update courses
DROP POLICY IF EXISTS "admin_update_all_courses" ON vet_courses;
CREATE POLICY "admin_update_all_courses"
ON vet_courses
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Admin can update job offers
DROP POLICY IF EXISTS "admin_update_all_jobs" ON job_offers;
CREATE POLICY "admin_update_all_jobs"
ON job_offers
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);
```

ثم شغّله في Supabase SQL Editor.

---

## ✅ النتيجة النهائية:

| Tab | View | Edit | Delete |
|-----|------|------|--------|
| Books | ✅ | ✅ | ✅ |
| Courses | ✅ | ✅ | ✅ |
| Jobs | ✅ | ✅ | ✅ |
| Vet Supplies | ✅ | ✅ | ✅ |
| Offers | ✅ | ✅ | ✅ |
| Surgical Tools | ✅ | ✅ | ✅ |
| OCR Products | ✅ | ✅ | ✅ |

**كل شيء متكامل!** 🎉
