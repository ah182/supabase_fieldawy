-- ============================================
-- اختبار Webhooks يدوياً
-- ============================================

-- 1️⃣ إضافة منتج تجريبي
INSERT INTO products (id, name, company) 
VALUES (gen_random_uuid(), 'Webhook Test Product', 'Test Company');

-- 2️⃣ تحديث منتج (لاختبار UPDATE webhook)
UPDATE products 
SET name = 'Updated Webhook Test'
WHERE name = 'Webhook Test Product';

-- 3️⃣ إضافة أداة جراحية
INSERT INTO surgical_tools (tool_name, company)
VALUES ('Test Forceps', 'Medline');

-- 4️⃣ إضافة منتج في distributor_products مع سعر
INSERT INTO distributor_products (
  id,
  distributor_id,
  product_id,
  package,
  price
) VALUES (
  'webhook_test_001',
  (SELECT id FROM users WHERE role = 'distributor' LIMIT 1),
  (SELECT id FROM products LIMIT 1),
  'Box of 100',
  100.00
);

-- 5️⃣ تحديث السعر (لاختبار Price Action)
UPDATE distributor_products
SET price = 150.00
WHERE id = 'webhook_test_001';

-- ============================================
-- ملاحظة: بعد كل استعلام، انتظر 2-3 ثواني
-- وافحص terminal حيث يعمل notification server
-- يجب أن تشاهد: 📩 تلقي webhook من Supabase
-- ============================================
