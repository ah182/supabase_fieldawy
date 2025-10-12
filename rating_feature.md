ميزة: طلب تقييم منتج (Review Request)

> ملف شامل جاهز للإرسال للـ Agent/Coder. يحتوي على: وصف الميزة، SQL جاهز للتنفيذ على Supabase (Postgres)، منطق الأعمال، أمثلة API (REST), Postman collection (JSON)، وإعدادات الإشعارات باستخدام FCM.




---

1. ملخص الميزة (موجز)

كل مستخدم يقدر يطلب تقييم لمنتج واحد فقط كل أسبوع (7 أيام).

كل منتج يمكن أن يُطلب له تقييم مرة واحدة فقط طوال عمر النظام (قيد فريد على product_id في جدول review_requests).

بعد إنشاء طلب التقييم، يستطيع المستخدمون إضافة تقييم (rating 1-5) وتعليق نصي.

التعليقات النصية مقيدة إلى أول 5 تعليقات لكل طلب. بعد اكتمال الـ5، يُمنع إضافة تعليقات نصية جديدة، لكن يمكن الاستمرار في إضافة تقييمات بالنجوم.

عدد التقييمات بالنجوم غير محدود.

عند الوصول للـ5 تعليقات، يتم إغلاق الخاصية الكتابية للطلب (is_active = false) بينما يبقى استقبال النجوم متاحًا.



---

2. ملفات/أسماء مقترحة

README (هذا الملف): feature_review_requests_README.md

SQL migration: migrations/2025_10_11_review_requests.sql

Postman collection: postman/ReviewRequests.postman_collection.json



---

3. SQL (Supabase / Postgres)

> شغّل هذا الملف كمِيجريشن على Supabase SQL editor أو عبر CLI.



-- migration: 2025_10_11_review_requests.sql

-- 1) table products مفترض موجود مسبقًا.
-- إذا كان غير موجود، حافظ على التوافق مع السكيمة الحالية.

-- 2) جدول طلبات التقييم
CREATE TABLE IF NOT EXISTS review_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL UNIQUE, -- قيد مهم: منتج واحد = طلب واحد فقط EVER
  requested_by uuid NOT NULL,
  requested_at timestamptz DEFAULT now(),
  is_active boolean DEFAULT true,
  comments_count int DEFAULT 0,
  closed_reason text, -- optional
  metadata jsonb, -- optional metadata
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT fk_product_review_request FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE INDEX IF NOT EXISTS idx_review_requests_requested_by ON review_requests(requested_by);
CREATE INDEX IF NOT EXISTS idx_review_requests_requested_at ON review_requests(requested_at);

-- 3) جدول التقييمات/التعليقات
CREATE TABLE IF NOT EXISTS product_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_request_id uuid REFERENCES review_requests(id) ON DELETE CASCADE,
  product_id uuid NOT NULL,
  user_id uuid NOT NULL,
  rating smallint NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  is_comment boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT one_review_per_user_per_request UNIQUE (review_request_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_product_reviews_product_id ON product_reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_request_id ON product_reviews(review_request_id);

-- 4) trigger لتحديث updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_review_requests_updated_at
BEFORE UPDATE ON review_requests
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_product_reviews_updated_at
BEFORE UPDATE ON product_reviews
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 5) index لبحث سريع في product_id في حالة وجود جدول كبير
CREATE INDEX IF NOT EXISTS idx_product_reviews_product_id_rating ON product_reviews(product_id, rating);

-- 6) وظيفة مساعدة: التأكد من عدم طلب المنتج أكثر من مرة (server-side guard)
-- (قيد UNIQUE على product_id كافي، لكن هذه دالة للمراجعة إن رغبت)


---

4. قواعد العمل (Business Logic) مفصّلة

4.1 إنشاء طلب تقييم (flow)

Endpoint: POST /api/review-requests

Body: { product_id, user_id }

خطوات التحقق (server-side):

1. هل المنتج موجود في جدول products؟ إذا لا -> 404 ProductNotFound.


2. هل يوجد review_requests بنفس product_id؟ إذا نعم -> 409 ProductAlreadyRequested.


3. هل قام user_id بإنشاء طلب آخر خلال آخر 7 أيام؟

SQL: SELECT 1 FROM review_requests WHERE requested_by = :user_id AND requested_at >= now() - interval '7 days' LIMIT 1.

إن وجد -> 429 WeeklyLimitExceeded.



4. إن لم توجد أي مشكلة -> أنشئ review_requests جديد.


5. أرسل إشعار (راجع فقرة الإشعارات).



Response success: 201 Created مع جسم يحتوي تفاصيل الطلب.


4.2 إضافة تقييم/تعليق

Endpoint: POST /api/review-requests/{id}/reviews

Body: { user_id, rating, comment? }

تحققات:

1. هل review_request موجود؟ إذا لا -> 404.


2. هل المستخدم قام بالتقييم سابقًا لنفس الطلب؟ (unique constraint) -> 409 AlreadyReviewed.


3. إذا comment موجود:

تحقق comments_count < 5. إذا >=5 -> ارجع 409 CommentLimitReached (لكن اسمح بتسجيل الـrating بدون comment).



4. أي إدخال يجب يتم في Transaction atomic:

Insert في product_reviews مع is_comment = (comment IS NOT NULL).

لو comment موجود: UPDATE review_requests SET comments_count = comments_count + 1 WHERE id = :id.

لو بعد الزيادة comments_count = 5 -> UPDATE review_requests SET is_active = false WHERE id = :id.




Response success: 201 Created مع التقييم الجديد ورقم التعليقات الحالي.


4.3 عرض حالة الطلب / جلب التعليقات

GET /api/review-requests/{id}

يعيد: تفاصيل الطلب، comments_count, قائمة أول 5 تعليقات (مع user_id, rating, comment, created_at)، ومتوسط التقييم (avg).


GET /api/products/{id}/reviews

يعيد ملخص product-level: avg_rating, total_ratings, review_request_exists, comments (أول 5 إذا وُجد طلب).



4.4 قواعد إضافية

لا تسمح بإعادة طلب نفس المنتج (قيد UNIQUE). إذا أردت قابلية التكرار بعد مرور زمن، يجب إزالة الـUNIQUE وتغيير المنطق.

السماح بتسجيل rating حتى لو is_active = false (لأننا نريد تجميع نجوم كثير).

من الأفضل تسجيل مصدر الـrating (is_verified) إن كان المستخدم اشتراه فعليًا — حقل إضافي في product_reviews مثل is_verified boolean DEFAULT false.



---

5. API Spec (OpenAPI-like short)

> لاحقًا يمكن تحويلها إلى Swagger/OpenAPI، الآن أمثلة واضحة للـ Agent.



5.1 POST /api/review-requests

Request body:


{ "product_id": "uuid", "user_id": "uuid" }

Success 201:


{
  "id": "uuid",
  "product_id": "uuid",
  "requested_by": "uuid",
  "requested_at": "2025-10-11T...",
  "comments_count": 0,
  "is_active": true
}

Errors:

409 ProductAlreadyRequested

429 WeeklyLimitExceeded




---

5.2 POST /api/review-requests/{id}/reviews

Request body:


{ "user_id": "uuid", "rating": 4, "comment": "اختياري" }

Success 201: created review object.

Errors:

400/409 CommentLimitReached

409 AlreadyReviewed




---

5.3 GET /api/review-requests/{id}

Response:


{
  "id": "uuid",
  "product_id": "uuid",
  "requested_by": "uuid",
  "requested_at": "...",
  "comments_count": 3,
  "is_active": true,
  "avg_rating": 4.2,
  "comments": [ { "user_id": "uuid", "rating": 5, "comment": "...", "created_at": "..." }, ... ]
}


---

6. Postman Collection (ملاحظة: نسخة JSON جاهزة للتصدير)

> الصق هذا الـ JSON في Postman → Import → File أو Raw Text.



{
  "info": {
    "name": "ReviewRequests API",
    "_postman_id": "review-requests-collection-2025-10-11",
    "description": "Collection for Review Requests feature",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Create Review Request",
      "request": {
        "method": "POST",
        "header": [
          { "key": "Content-Type", "value": "application/json" },
          { "key": "Authorization", "value": "Bearer {{JWT}}" }
        ],
        "body": {
          "mode": "raw",
          "raw": "{ \"product_id\": \"{{product_id}}\", \"user_id\": \"{{user_id}}\" }"
        },
        "url": { "raw": "{{BASE_URL}}/api/review-requests", "host": [ "{{BASE_URL}}" ], "path": [ "api", "review-requests" ] }
      },
      "response": []
    },
    {
      "name": "Add Review to Request",
      "request": {
        "method": "POST",
        "header": [
          { "key": "Content-Type", "value": "application/json" },
          { "key": "Authorization", "value": "Bearer {{JWT}}" }
        ],
        "body": {
          "mode": "raw",
          "raw": "{ \"user_id\": \"{{user_id}}\", \"rating\": 5, \"comment\": \"جيد جدا\" }"
        },
        "url": { "raw": "{{BASE_URL}}/api/review-requests/{{request_id}}/reviews", "host": [ "{{BASE_URL}}" ], "path": [ "api", "review-requests", "{{request_id}}", "reviews" ] }
      },
      "response": []
    },
    {
      "name": "Get Review Request",
      "request": {
        "method": "GET",
        "header": [ { "key": "Authorization", "value": "Bearer {{JWT}}" } ],
        "url": { "raw": "{{BASE_URL}}/api/review-requests/{{request_id}}", "host": [ "{{BASE_URL}}" ], "path": [ "api", "review-requests", "{{request_id}}" ] }
      },
      "response": []
    },
    {
      "name": "Get Product Reviews",
      "request": {
        "method": "GET",
        "header": [ { "key": "Authorization", "value": "Bearer {{JWT}}" } ],
        "url": { "raw": "{{BASE_URL}}/api/products/{{product_id}}/reviews", "host": [ "{{BASE_URL}}" ], "path": [ "api", "products", "{{product_id}}", "reviews" ] }
      },
      "response": []
    }
  ]
}


---

7. Notifications (FCM) — التصميم العملي

7.1 منطق الإرسال

لا تُرسل إشعارًا إلى كل المستخدمين. استخدم استهداف ذكي:

جمهور مستهدف (best practice):

المستخدمين الذين اشتروا المنتج سابقًا.

المستخدمين الذين زاروا صفحة المنتج في آخر 90 يومًا.

أو مشتركين في فئة المنتج (category subscribers).

أو مجموعة من المستخدمين النشطين (مثلاً N عشوائي من الأكثر نشاطًا).



7.2 رسائل مقترحة (payload)

Title: "طلب تقييم لمنتج جديد"

Body: "المستخدم {{username}} طلب تقييم لدواء {{product_name}} — شاركنا رأيك!"

Data (deep link): { "action": "open_review_request", "review_request_id": "uuid" }


7.3 مثال إرسال عبر FCM HTTP v1 (server-side)

استخدم مكتبات Admin SDK (Node/Java/Python) أو طلب HTTP إلى endpoint مع OAuth token من service account.


// pseudocode (Node.js)
const message = {
  token: targetFcmToken,
  notification: { title: 'طلب تقييم لمنتج جديد', body: 'المستخدم X طلب تقييم لدواء Y — شارك رأيك!' },
  data: { action: 'open_review_request', review_request_id: '...' }
};
admin.messaging().send(message).then(...)

7.4 سياسة الإرسال

لا تبعث أكثر من إشعارين لكل مستخدم في اليوم بخصوص طلبات تقييم.

إن أردت، بديل أخف: لا ترسل Push بل ضع قسمًا داخل التطبيق "طلبات تقييم جديدة" مع badge يومي.



---

8. نقاط الانتباه (Edge Cases & Concurrency)

Race on create: وجود 2 users يحاولوا طلب نفس المنتج في نفس اللحظة → اعتمد على UNIQUE constraint على product_id والتقاط الخطأ وارجاع 409.

Atomic update: زيادة comments_count وقراءة قيمته يجب أن تتم داخل TRANSACTION لمنع حالات تنافس.

AlreadyReviewed: قيد UNIQUE في product_reviews(review_request_id, user_id) يمنع أن المستخدم نفسه يراجع نفس الطلب مرتين.

Moderation: إضافة آلية flag/report وإمكانية إزالة تعليق بواسطة Admin.



---

9. مؤشرات قياس (KPIs)

نسبة الطلبات التي تصل إلى 5 تعليقات.

متوسط الوقت للوصول إلى 5 تعليقات (hours/days).

conversion من إشعار → زيارة → تقييم.

average rating per product.



---

10. اختبارات مقترحة (Test Cases)

إنشاء طلب ناجح.

فشل إنشـاء طلب لوجود طلب سابق (409).

فشل إنشـاء طلب لتجاوز حد الأسبوع (429).

إضافة comment أثناء وجود أقل من 5 تعليقات (201).

محاولة إضافة comment بعد اكتمال الـ5 (409) مع السماح rating فقط.

محاولة إضافة rating/comment مرتين من نفس المستخدم (409).

تحقق من إيقاف is_active بعد الوصول للـ5.

سباق (two parallel requests to create same product request) -> 1 success + 1 conflict.



---

11. مهمة الـ Agent — Checklist للتنفيذ

1. تشغيل ملف الـ SQL/migration.


2. تنفيذ API endpoints (controllers/handlers):

POST /api/review-requests

POST /api/review-requests/{id}/reviews

GET /api/review-requests/{id}

GET /api/products/{id}/reviews



3. حماية endpoints بمصادقة (JWT) وتطبيق rate-limits.


4. تنفيذ منطق weekly limit و UNIQUE constraint handling.


5. تنفيذ atomic transaction عند إضافة review/comment.


6. ربط FCM لإرسال إشعارات مستهدفة.


7. إضافة moderation endpoints (optional): DELETE review, FLAG review.


8. إضافة logging + events tracking (request_created, review_submitted, comment_limit_reached).


9. إضافة unit & integration tests.




---

12. ملاحظات ومقترحات مستقبلية (اختياري)

إضافة حقل is_verified في product_reviews للتحقق إن كان المراجع اشتري المنتج فعلاً.

تغيير سياسة السماح بإعادة طلب منتج بعد مدة طويلة أو بعد تحديث المنتج (مثلاً 6 أشهر أو عند تغيير التركيبة).

نظام شارات/نقاط لتحفيز المشاركين الأوائل (مثلاً أول 5 يكتبوا تعليقًا يحصلوا على +10 نقاط).



---

13. مرفقات

Postman collection: postman/ReviewRequests.postman_collection.json (مضمن في هذا المستند أعلاه).

SQL migration: migrations/2025_10_11_review_requests.sql (مضمن أعلاه).



---

انتهى README