# 📋 بنية جداول الأدوات الجراحية

## 🎯 التعديل الرئيسي: 
**الوصف الآن في جدول الموزعين** - كل موزع يكتب وصفه الخاص! ⭐

---

## 📊 الجداول

### 1️⃣ `surgical_tools` - الكتالوج العام

معلومات الأداة الأساسية المشتركة بين جميع الموزعين:

| الحقل | النوع | إجباري؟ | الوصف |
|-------|------|---------|-------|
| `id` | UUID | ✅ | المعرف الفريد |
| `tool_name` | TEXT | ✅ | اسم الأداة |
| `company` | TEXT | ❌ | الشركة المصنعة (اختياري) |
| `image_url` | TEXT | ❌ | رابط الصورة على Cloudinary |
| `created_by` | UUID | ❌ | من أضاف الأداة |
| `created_at` | TIMESTAMPTZ | ✅ | وقت الإنشاء |
| `updated_at` | TIMESTAMPTZ | ✅ | وقت آخر تحديث |

---

### 2️⃣ `distributor_surgical_tools` - أدوات الموزعين

معلومات خاصة بكل موزع (السعر + الوصف الخاص به):

| الحقل | النوع | إجباري؟ | الوصف |
|-------|------|---------|-------|
| `id` | UUID | ✅ | المعرف الفريد |
| `distributor_id` | UUID | ✅ | معرف الموزع |
| `distributor_name` | TEXT | ✅ | اسم الموزع |
| `surgical_tool_id` | UUID | ✅ | معرف الأداة |
| **`description`** | **TEXT** | **✅** | **وصف الموزع الخاص للأداة** ⭐ |
| `price` | NUMERIC(12,2) | ✅ | سعر الأداة |
| `stock_quantity` | INTEGER | ❌ | الكمية المتاحة (للمستقبل) |
| `is_available` | BOOLEAN | ❌ | هل متاح للبيع؟ |
| `created_at` | TIMESTAMPTZ | ✅ | وقت الإضافة |
| `updated_at` | TIMESTAMPTZ | ✅ | وقت آخر تحديث |

**Constraint**: `UNIQUE(distributor_id, surgical_tool_id)` - منع التكرار

---

## 🔍 مثال عملي

### السيناريو:
ثلاثة موزعين يبيعون نفس الأداة "Surgical Scissors":

```sql
-- 1. الأداة في الكتالوج العام (مرة واحدة فقط)
surgical_tools:
├─ id: "abc-123"
├─ tool_name: "Surgical Scissors"
├─ company: "MedTech Pro"
└─ image_url: "https://..."

-- 2. كل موزع يضيف الأداة بسعره ووصفه الخاص
distributor_surgical_tools:

├─ موزع أحمد:
│  ├─ surgical_tool_id: "abc-123"
│  ├─ description: "مقص جراحي عالي الجودة، استانلس استيل، مناسب للعيادات البيطرية"
│  └─ price: 150.00 EGP
│
├─ موزع محمد:
│  ├─ surgical_tool_id: "abc-123"
│  ├─ description: "مقص جراحي ألماني الصنع، ضمان سنتين، توصيل مجاني"
│  └─ price: 175.00 EGP
│
└─ موزع فاطمة:
   ├─ surgical_tool_id: "abc-123"
   ├─ description: "مقص جراحي ممتاز، مستورد، عرض خاص لفترة محدودة!"
   └─ price: 140.00 EGP
```

---

## 🔐 الحماية (RLS Policies)

- ✅ **القراءة**: الجميع يمكنهم قراءة الكتالوج والأدوات
- ✅ **الإضافة**: المستخدمون المسجلون فقط
- ✅ **التعديل/الحذف**: كل موزع يعدل أدواته فقط

---

## ⚡ الأداء (Indexes)

- Full-text search على اسم الأداة
- Full-text search على الوصف ⭐
- فهرس على الموزع والأداة
- فهرس على المنتجات المتاحة

---

## 🛠️ الدوال المساعدة

### `get_distributor_surgical_tools(dist_id)`
جلب جميع أدوات موزع معين مع التفاصيل الكاملة (بما فيها وصفه الخاص)

### `search_surgical_tools(search_query)`
البحث في جميع الأدوات (الاسم، الشركة، الوصف)

---

## 📱 في Flutter

```dart
// المثال:
SurgicalToolModel(
  id: 'abc-123',
  toolName: 'Surgical Scissors',
  company: 'MedTech Pro',
  imageUrl: 'https://...',
  
  // معلومات الموزع الخاصة:
  description: 'مقص جراحي عالي الجودة...',  // وصف الموزع ⭐
  price: 150.00,
  distributorName: 'أحمد للمستلزمات الطبية',
  isAvailable: true,
);
```

---

## ✅ المزايا

| الميزة | الفائدة |
|-------|---------|
| 🎯 **مرونة في الوصف** | كل موزع يكتب ما يميز منتجه |
| 💰 **تنافسية السعر** | نفس الأداة بأسعار مختلفة |
| 📦 **إعادة الاستخدام** | الأداة تُحفظ مرة واحدة |
| 🔍 **بحث أفضل** | البحث في أوصاف الموزعين |
| 🚀 **أداء عالي** | Indexes على جميع الحقول المهمة |

---

## 📝 التوافق مع OCR Screen

عند `isFromSurgicalTools = true`:
- ✅ Tool Name → `surgical_tools.tool_name`
- ✅ Company (Optional) → `surgical_tools.company`
- ✅ Description → `distributor_surgical_tools.description` ⭐
- ✅ Price → `distributor_surgical_tools.price`
- ✅ Image → `surgical_tools.image_url`
