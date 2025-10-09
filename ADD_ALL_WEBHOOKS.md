# 🚀 إضافة جميع Webhooks المطلوبة

## ✅ ما يعمل الآن:
- Webhook لـ `surgical_tools` يعمل!

## ⏳ ما نحتاج إضافته:

نحتاج إضافة **4 webhooks** إضافية للجداول الأخرى.

---

## 📋 القائمة الكاملة

### Webhook 1: products ✅
```
Name: products_notifications
Table: products
Events: ☑️ Insert  ☑️ Update
URL: https://little-mice-ask.loca.lt/api/notify/product-change
Headers: Content-Type: application/json
```

---

### Webhook 2: distributor_products ✅
```
Name: distributor_products_notifications
Table: distributor_products
Events: ☑️ Insert  ☑️ Update
URL: https://little-mice-ask.loca.lt/api/notify/product-change
Headers: Content-Type: application/json
```

---

### Webhook 3: surgical_tools ✅ (موجود بالفعل!)
```
Name: surgical_tools_notifications
Table: surgical_tools
Events: ☑️ Insert  ☑️ Update
URL: https://little-mice-ask.loca.lt/api/notify/product-change
Headers: Content-Type: application/json
```

---

### Webhook 4: distributor_surgical_tools ⚠️ (الأهم!)
```
Name: distributor_surgical_tools_notifications
Table: distributor_surgical_tools
Events: ☑️ Insert  ☑️ Update
URL: https://little-mice-ask.loca.lt/api/notify/product-change
Headers: Content-Type: application/json
```

**هذا هو الجدول الذي يستخدمه التطبيق عند إضافة أداة!**

---

### Webhook 5: offers ✅
```
Name: offers_notifications
Table: offers
Events: ☑️ Insert  ☑️ Update
URL: https://little-mice-ask.loca.lt/api/notify/product-change
Headers: Content-Type: application/json
```

---

## 🎯 خطوات الإضافة (لكل webhook):

### 1. في Supabase Dashboard:
```
Database > Webhooks > Create a new hook
```

### 2. املأ البيانات:
```
Name: [من القائمة أعلاه]
Schema: public
Table: [من القائمة أعلاه]
Events: ☑️ Insert  ☑️ Update
Type: HTTP Request
Method: POST
URL: https://little-mice-ask.loca.lt/api/notify/product-change
```

### 3. أضف Header:
```
Content-Type: application/json
```

### 4. اضغط: Confirm ✅

---

## 🧪 اختبار كل webhook

### Test 1: products
```sql
INSERT INTO products (id, name, company) 
VALUES (gen_random_uuid(), 'Test Product', 'GSK');
```

### Test 2: distributor_products
```sql
INSERT INTO distributor_products (id, distributor_id, product_id, package, price)
VALUES (gen_random_uuid(), auth.uid(), (SELECT id FROM products LIMIT 1), 'Box', 100);
```

### Test 3: distributor_surgical_tools (الأهم!)
```sql
INSERT INTO distributor_surgical_tools (
  distributor_id,
  distributor_name,
  surgical_tool_id,
  description,
  price
) VALUES (
  auth.uid(),
  'Test Distributor',
  (SELECT id FROM surgical_tools LIMIT 1),
  'Test Tool Description',
  150.00
);
```

### Test 4: offers
```sql
INSERT INTO offers (
  product_id,
  is_ocr,
  user_id,
  price,
  expiration_date,
  description
) VALUES (
  (SELECT id::text FROM products LIMIT 1),
  false,
  auth.uid(),
  50.00,
  NOW() + INTERVAL '7 days',
  'خصم 20%'
);
```

---

## ✅ بعد إضافة جميع Webhooks:

**جرب من التطبيق:**
1. أضف أداة جراحية
2. يجب أن يصل إشعار! 🎉

---

## 🎯 الأولوية:

**أضف هذا Webhook أولاً:**
```
Table: distributor_surgical_tools
```

**لأن التطبيق يستخدمه عند إضافة أدوات!**

---

## 📊 ملخص

| الجدول | متى يُستخدم | أولوية |
|--------|-------------|---------|
| `products` | إضافة منتج للكتالوج العام | متوسطة |
| `distributor_products` | إضافة منتج من الموزع | عالية |
| `surgical_tools` | إضافة أداة للكتالوج العام | متوسطة |
| `distributor_surgical_tools` | إضافة أداة من الموزع | **عالية جداً** ⚠️ |
| `offers` | إضافة عرض | عالية |

---

## 💡 نصيحة

**أضفهم الآن واحد تلو الآخر**، واختبر كل واحد بعد إضافته!

---

**ابدأ بـ `distributor_surgical_tools` الآن! 🚀**
