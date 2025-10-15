# إضافة Edit & Delete لـ Catalog & Distributor Products

## ✅ تم بالفعل:
- ✅ `adminUpdateProduct()` - تعديل منتجات Catalog
- ✅ `adminDeleteProduct()` - حذف منتجات Catalog
- ✅ `adminUpdateDistributorProduct()` - تعديل منتجات Distributor
- ✅ `adminDeleteDistributorProduct()` - حذف منتجات Distributor

---

## الخطوة 1️⃣: إضافة RLS Policies في Supabase

افتح **Supabase SQL Editor** وشغّل هذا:

```sql
-- ============================================
-- PRODUCTS TABLE - Admin Edit/Delete
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_update_all_products" ON products;
DROP POLICY IF EXISTS "admin_delete_all_products" ON products;

-- Admin can update all products
CREATE POLICY "admin_update_all_products"
ON products
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Admin can delete all products
CREATE POLICY "admin_delete_all_products"
ON products
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- ============================================
-- DISTRIBUTOR_PRODUCTS TABLE - Admin Edit/Delete
-- ============================================

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "admin_update_all_distributor_products" ON distributor_products;
DROP POLICY IF EXISTS "admin_delete_all_distributor_products" ON distributor_products;

-- Admin can update all distributor products
CREATE POLICY "admin_update_all_distributor_products"
ON distributor_products
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Admin can delete all distributor products
CREATE POLICY "admin_delete_all_distributor_products"
ON distributor_products
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() AND role = 'admin'
  )
);
```

---

## الخطوة 2️⃣: تعديل Catalog Products Tab UI

في `product_management_screen.dart`, في `_CatalogProductsDataSource` class:

### 1. إضافة Edit و Delete Buttons

ابحث عن السطر اللي فيه:
```dart
DataCell(Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.visibility, size: 20), tooltip: 'View', onPressed: () => _showCatalogDetails(product))]))
```

**استبدله بـ:**
```dart
DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
  IconButton(icon: const Icon(Icons.visibility, size: 20), tooltip: 'View', onPressed: () => _showCatalogDetails(product)),
  IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit', onPressed: () => _showCatalogEditDialog(product)),
  IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmCatalogDelete(product)),
]))
```

### 2. إضافة Edit Dialog

أضف هذا الكود في `_CatalogProductsDataSource` class بعد `_showCatalogDetails`:

```dart
  void _showCatalogEditDialog(ProductModel product) {
    final nameController = TextEditingController(text: product.name);
    final companyController = TextEditingController(text: product.company);
    final activePrincipleController = TextEditingController(text: product.activePrinciple ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Catalog Product'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: companyController,
                  decoration: const InputDecoration(labelText: 'Company'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: activePrincipleController,
                  decoration: const InputDecoration(labelText: 'Active Principle (Optional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final company = companyController.text.trim();
              final activePrinciple = activePrincipleController.text.trim();

              if (name.isEmpty || company.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill Name and Company')),
                );
                return;
              }

              try {
                Navigator.pop(context);
                final success = await ref.read(productRepositoryProvider).adminUpdateProduct(
                  id: product.id,
                  name: name,
                  company: company,
                  activePrinciple: activePrinciple.isEmpty ? null : activePrinciple,
                );

                if (success) {
                  ref.invalidate(adminAllProductsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Product updated successfully'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Update failed'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
```

### 3. إضافة Delete Confirmation

أضف هذا الكود أيضاً:

```dart
  void _confirmCatalogDelete(ProductModel product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?\n\nThis will permanently remove it from the catalog.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                final success = await ref.read(productRepositoryProvider).adminDeleteProduct(product.id);

                if (success) {
                  ref.invalidate(adminAllProductsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Product deleted successfully'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Delete failed'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
```

---

## الخطوة 3️⃣: تعديل Distributor Products Tab UI

في `_DistributorProductsDataSource` class:

### 1. إضافة Edit و Delete Buttons

ابحث عن:
```dart
DataCell(Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.visibility, size: 20), tooltip: 'View', onPressed: () => _showDistributorDetails(product))]))
```

**استبدله بـ:**
```dart
DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
  IconButton(icon: const Icon(Icons.visibility, size: 20), tooltip: 'View', onPressed: () => _showDistributorDetails(product)),
  IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit Price', onPressed: () => _showDistributorEditDialog(product)),
  IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDistributorDelete(product)),
]))
```

### 2. إضافة Edit Dialog

أضف في `_DistributorProductsDataSource`:

```dart
  void _showDistributorEditDialog(ProductModel product) {
    final priceController = TextEditingController(text: product.price?.toString() ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Distributor Product Price'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Product: ${product.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Distributor: ${product.distributorId}'),
                Text('Package: ${product.selectedPackage ?? "N/A"}'),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price (EGP)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final priceText = priceController.text.trim();
              final price = double.tryParse(priceText);

              if (price == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid price')),
                );
                return;
              }

              try {
                Navigator.pop(context);
                final success = await ref.read(productRepositoryProvider).adminUpdateDistributorProduct(
                  distributorId: product.distributorId!,
                  productId: product.id,
                  package: product.selectedPackage ?? '',
                  price: price,
                );

                if (success) {
                  ref.invalidate(adminAllProductsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Price updated successfully'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Update failed'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
```

### 3. إضافة Delete Confirmation

```dart
  void _confirmDistributorDelete(ProductModel product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Distributor Product'),
        content: Text('Are you sure you want to delete "${product.name}" from distributor "${product.distributorId}"?\n\nPackage: ${product.selectedPackage}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                final success = await ref.read(productRepositoryProvider).adminDeleteDistributorProduct(
                  distributorId: product.distributorId!,
                  productId: product.id,
                  package: product.selectedPackage ?? '',
                );

                if (success) {
                  ref.invalidate(adminAllProductsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Product deleted successfully'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Delete failed'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
```

---

## 📊 النتيجة النهائية:

| Tab | View | Edit | Delete |
|-----|:----:|:----:|:------:|
| **Catalog Products** | ✅ | ✅ | ✅ |
| **Distributor Products** | ✅ | ✅ | ✅ |
| Vet Supplies | ✅ | ✅ | ✅ |
| Offers | ✅ | ✅ | ✅ |
| Surgical Tools | ✅ | ✅ | ✅ |
| OCR Products | ✅ | ✅ | ✅ |
| Books | ✅ | ✅ | ✅ |
| Courses | ✅ | ✅ | ✅ |
| Jobs | ✅ | ✅ | ✅ |

---

## 🎨 Edit Fields:

**Catalog Products:**
- Product Name
- Company
- Active Principle (optional)

**Distributor Products:**
- Price (السعر فقط - لأن Product و Package ثوابت)

---

## ⚠️ ملاحظات مهمة:

### Catalog Products:
- ✅ تعديل الاسم والشركة والمادة الفعالة
- ✅ الحذف يحذف من جدول `products`
- ⚠️ **الحذف هيحذف كل ارتباطات المنتج من distributor_products**

### Distributor Products:
- ✅ تعديل السعر فقط (لأن المنتج والباكدج ثوابت)
- ✅ الحذف يحذف من جدول `distributor_products`
- ✅ لا يؤثر على جدول `products` الأساسي

---

## 🚀 الخطوات بالترتيب:

1. ✅ شغّل الـ SQL في Supabase (الخطوة 1)
2. ✅ أضف Edit/Delete للـ Catalog Products (الخطوة 2)
3. ✅ أضف Edit/Delete للـ Distributor Products (الخطوة 3)
4. ✅ اختبر التعديل والحذف

---

**كل المنتجات الآن عندها Edit و Delete! 🎉**
