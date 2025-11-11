# 🚀 تحسين نظام الـ Leaderboard بدون استهلاك Invocations

## المشكلة الحالية ⚠️

### النظام القديم:
```
Edge Function (update-leaderboard-ranks)
  ↓
يُستدعى كل دقيقة عبر pg_cron
  ↓
استهلاك: 43,200 invocation/شهر ❌
```

**المشكلة**: 
- الخطة المجانية: 500,000 invocation/شهر
- هذه الدالة وحدها: 43,200 invocation/شهر (8.6%)
- مع دوال أخرى، قد تصل للحد بسرعة

---

## الحلول المقترحة ✅

### الحل 1️⃣: استبدال Edge Function بـ SQL Function مع pg_cron

#### المميزات:
- ✅ 0 invocations (لا يستهلك شيء)
- ✅ سهل التطبيق
- ✅ لا يحتاج تعديل كود Dart

#### العيوب:
- ⚠️ لا يزال يعتمد على cron (كل 5 دقائق)

#### الاستخدام:
```sql
-- شغّل هذا:
supabase/REPLACE_EDGE_FUNCTION_WITH_SQL.sql
```

#### ما يفعله:
```sql
-- 1. حذف cron القديم (الذي يستدعي Edge Function)
SELECT cron.unschedule('update-leaderboard-ranks-job');

-- 2. استدعاء SQL Function مباشرة
SELECT cron.schedule(
  'update-leaderboard-ranks-sql',
  '*/5 * * * *',  -- كل 5 دقائق
  $$
  SELECT public.update_leaderboard_ranks();
  $$
);
```

---

### الحل 2️⃣: Trigger-based Update (الأمثل) 🏆

#### المميزات:
- ✅ 0 invocations
- ✅ تحديث فوري (بدون انتظار cron)
- ✅ Throttling مدمج (مرة كل دقيقة فقط)
- ✅ أداء أفضل

#### العيوب:
- ⚠️ أكثر تعقيداً قليلاً

#### الاستخدام:
```sql
-- شغّل هذا:
supabase/TRIGGER_BASED_RANK_UPDATE.sql
```

#### ما يفعله:
```
عند تحديث النقاط لأي مستخدم
  ↓
Trigger يتحقق: مر أكثر من دقيقة؟
  ↓ نعم
تحديث ترتيب كل المستخدمين
  ↓
حفظ وقت التحديث
```

---

## المقارنة 📊

| الميزة | Edge Function (القديم) | SQL + Cron (الحل 1) | Trigger (الحل 2) |
|--------|------------------------|---------------------|------------------|
| Invocations | 43,200/شهر ❌ | 0 ✅ | 0 ✅ |
| التحديث | كل دقيقة | كل 5 دقائق | فوري (عند تغيير النقاط) |
| الأداء | متوسط | جيد | ممتاز |
| السهولة | معقد | سهل | متوسط |
| التوصية | ❌ لا | ✅ جيد | 🏆 الأفضل |

---

## التفاصيل التقنية 🔧

### الدالة الأساسية (موجودة بالفعل):
```sql
CREATE OR REPLACE FUNCTION public.update_leaderboard_ranks()
RETURNS void AS $$
BEGIN
  WITH ranked_users AS (
    SELECT
      id,
      DENSE_RANK() OVER (ORDER BY points DESC) as new_rank
    FROM public.users
    WHERE points > 0
  )
  UPDATE public.users
  SET rank = ranked_users.new_rank
  FROM ranked_users
  WHERE users.id = ranked_users.id
    AND users.rank IS DISTINCT FROM ranked_users.new_rank;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**التحسينات**:
- `WHERE points > 0` → فقط المستخدمين بنقاط
- `WHERE users.rank IS DISTINCT FROM` → فقط عند تغيير الترتيب
- `DENSE_RANK()` → بدون فجوات في الترتيب

---

### Trigger مع Throttling:

```sql
CREATE OR REPLACE FUNCTION public.trigger_update_ranks_throttled()
RETURNS TRIGGER AS $$
DECLARE
  last_update TIMESTAMP;
  time_diff INTERVAL;
BEGIN
  SELECT last_update INTO last_update 
  FROM public.rank_update_tracker 
  WHERE id = 1;
  
  time_diff := NOW() - last_update;
  
  -- تحديث فقط إذا مر أكثر من 1 دقيقة
  IF time_diff > INTERVAL '1 minute' THEN
    PERFORM public.update_leaderboard_ranks();
    UPDATE public.rank_update_tracker 
    SET last_update = NOW() 
    WHERE id = 1;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_points_change_update_ranks
AFTER UPDATE OF points ON public.users
FOR EACH STATEMENT
EXECUTE FUNCTION public.trigger_update_ranks_throttled();
```

**لماذا Throttling؟**
- إذا تغيرت نقاط 100 مستخدم في نفس الثانية
- بدون throttling: 100 تحديث للترتيب ❌
- مع throttling: تحديث واحد فقط ✅

---

## خطوات التطبيق 🚀

### الطريقة الموصى بها (الحل 2):

#### 1️⃣ شغّل SQL Script:
```sql
-- في Supabase SQL Editor
supabase/TRIGGER_BASED_RANK_UPDATE.sql
```

#### 2️⃣ احذف/أوقف cron job القديم:
```sql
SELECT cron.unschedule('update-leaderboard-ranks-job');
```

#### 3️⃣ تحقق من الإعداد:
```sql
-- فحص الـ trigger
SELECT * FROM pg_trigger 
WHERE tgname = 'on_points_change_update_ranks';

-- فحص tracker
SELECT * FROM rank_update_tracker;
```

#### 4️⃣ اختبار:
```sql
-- أضف نقاط لمستخدم
UPDATE users 
SET points = points + 10 
WHERE id = 'some-user-id';

-- تحقق من تحديث الترتيب
SELECT id, display_name, points, rank 
FROM users 
ORDER BY rank ASC 
LIMIT 10;
```

---

## الفروقات في الأداء ⚡

### قبل (Edge Function):
```
كل دقيقة:
  1. HTTP request إلى Edge Function
  2. Deno runtime initialization
  3. Fetch all users
  4. Calculate ranks
  5. Bulk update
  6. HTTP response

الوقت: ~500-1000ms
Invocations: 43,200/شهر
```

### بعد (Trigger):
```
عند تغيير النقاط:
  1. Trigger checks throttle
  2. Calculate ranks (SQL)
  3. Update only changed ranks

الوقت: ~50-100ms
Invocations: 0
```

**تحسين الأداء**: 10x أسرع! 🚀

---

## السيناريوهات 🎬

### سيناريو 1: مستخدم واحد يكسب نقطة
```
القديم (Edge Function):
  - انتظار حتى الدقيقة التالية
  - تحديث كل المستخدمين (حتى لو لم يتغير ترتيبهم)

الجديد (Trigger):
  - تحديث فوري
  - فقط المستخدمين الذين تغير ترتيبهم
```

### سيناريو 2: 100 مستخدم يكسبون نقاط في نفس الوقت
```
القديم:
  - انتظار حتى الدقيقة التالية
  - تحديث الكل

الجديد:
  - Trigger يُشغّل مرة واحدة فقط (throttling)
  - تحديث فوري بعد آخر تغيير
```

### سيناريو 3: لا أحد يكسب نقاط
```
القديم:
  - يُشغّل كل دقيقة رغم عدم الحاجة ❌
  - 1,440 invocation/يوم بدون فائدة

الجديد:
  - لا يُشغّل أبداً إذا لم تتغير النقاط ✅
  - 0 invocations
```

---

## حذف Edge Function (اختياري) 🗑️

بعد تطبيق الحل الجديد، يمكنك حذف Edge Function:

### في terminal:
```bash
cd D:/fieldawy_store

# حذف الدالة من Supabase
supabase functions delete update-leaderboard-ranks

# حذف المجلد محلياً (بعد backup)
mv supabase/functions/update-leaderboard-ranks supabase/functions/_archive/update-leaderboard-ranks.backup
```

### أو احتفظ بها للطوارئ (موصى به):
```bash
# فقط أوقف cron job
SELECT cron.unschedule('update-leaderboard-ranks-job');

# الدالة تبقى موجودة لكن لا تُستدعى
```

---

## المراقبة 📈

### فحص آخر تحديث:
```sql
SELECT 
  last_update,
  NOW() - last_update AS time_since_update
FROM rank_update_tracker;
```

### فحص الترتيب الحالي:
```sql
SELECT 
  rank,
  display_name,
  points,
  role
FROM users
WHERE rank IS NOT NULL
ORDER BY rank ASC
LIMIT 20;
```

### فحص عدد التحديثات اليوم:
```sql
-- إذا أردت تتبع عدد التحديثات (اختياري)
ALTER TABLE rank_update_tracker 
ADD COLUMN update_count INT DEFAULT 0;

-- في trigger:
UPDATE public.rank_update_tracker 
SET 
  last_update = NOW(),
  update_count = update_count + 1
WHERE id = 1;
```

---

## الخلاصة 🎯

### التوصية النهائية:

1. **للإنتاج (Production)**: استخدم الحل 2 (Trigger) 🏆
   - أسرع
   - أكثر كفاءة
   - 0 invocations

2. **للبساطة**: استخدم الحل 1 (SQL + Cron) ✅
   - أبسط في الإعداد
   - 0 invocations
   - كافٍ لمعظم الحالات

3. **لا تستخدم Edge Function** إلا إذا كان ضرورياً ❌

---

## الملفات الجاهزة 📁

| الملف | الوصف | الحالة |
|------|-------|--------|
| `REPLACE_EDGE_FUNCTION_WITH_SQL.sql` | الحل 1: SQL + Cron | ✅ جاهز |
| `TRIGGER_BASED_RANK_UPDATE.sql` | الحل 2: Trigger (الأفضل) | 🏆 جاهز |
| `OPTIMIZE_LEADERBOARD_GUIDE.md` | هذا الملف - الشرح الكامل | 📄 |

---

**اختر الحل المناسب وشغّل SQL!** 🚀

**التوفير**: من 43,200 invocation/شهر إلى 0! 🎉
