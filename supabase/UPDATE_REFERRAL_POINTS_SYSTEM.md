# 🎯 تحديث نظام نقاط الدعوات

## التغييرات المطلوبة ✅

### النظام القديم ❌:
```
الداعي (inviter): 1 نقطة دائماً
المدعو (invited): 0 نقطة
```

### النظام الجديد ✅:
```
المدعو (invited): 2 نقطة دائماً
الداعي (inviter):
  - 1 نقطة إذا المدعو طبيب (doctor)
  - 2 نقطة إذا المدعو شركة/موزع (company/distributor)
```

---

## الملف المعدل 📝

### `supabase/functions/handle-referral/index.ts`

#### الكود القديم (السطر 73-82):
```typescript
// 3. Award a point to the inviter
const { error: pointsError } = await supabaseAdmin.rpc('increment_user_points', { 
  user_id_param: inviter_id, 
  points_to_add: 1  // ❌ نقطة واحدة دائماً
});

if (pointsError) {
  console.error(`Failed to award points to user ${inviter_id}:`, pointsError);
}
```

#### الكود الجديد ✅:
```typescript
// 3. Get the invited user's role to determine points
const { data: invitedUser, error: invitedUserError } = await supabaseAdmin
  .from('users')
  .select('role')
  .eq('id', invited_id)
  .single()

if (invitedUserError) {
  console.error(`Failed to get invited user role:`, invitedUserError);
}

const invitedRole = invitedUser?.role || 'doctor'; // default to doctor if role not found

// 4. Calculate points based on invited user's role
// Inviter gets: 1 point for doctor, 2 points for company/distributor
const inviterPoints = (invitedRole === 'company' || invitedRole === 'distributor') ? 2 : 1;

// Invited user always gets 2 points
const invitedPoints = 2;

// 5. Award points to both users
// Award points to inviter
const { error: inviterPointsError } = await supabaseAdmin.rpc('increment_user_points', { 
  user_id_param: inviter_id, 
  points_to_add: inviterPoints 
});

if (inviterPointsError) {
  console.error(`Failed to award ${inviterPoints} points to inviter ${inviter_id}:`, inviterPointsError);
}

// Award points to invited user
const { error: invitedPointsError } = await supabaseAdmin.rpc('increment_user_points', { 
  user_id_param: invited_id, 
  points_to_add: invitedPoints 
});

if (invitedPointsError) {
  console.error(`Failed to award ${invitedPoints} points to invited user ${invited_id}:`, invitedPointsError);
}
```

---

## المنطق 🔄

```
┌─────────────────────────────────────────┐
│ 1. إنشاء referral record                │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 2. جلب role المدعو من جدول users        │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 3. حساب النقاط:                         │
│    - inviterPoints:                     │
│      • doctor → 1 نقطة                  │
│      • company/distributor → 2 نقطة    │
│    - invitedPoints: 2 نقطة دائماً      │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 4. إضافة النقاط:                        │
│    - للداعي: inviterPoints              │
│    - للمدعو: invitedPoints (2)          │
└─────────────────────────────────────────┘
```

---

## أمثلة 📊

### مثال 1: دعوة طبيب
```
الداعي (Ali): role = 'distributor'
المدعو (Sara): role = 'doctor'

النقاط:
  - Ali (الداعي): +1 نقطة ✅ (لأن Sara طبيب)
  - Sara (المدعو): +2 نقطة ✅
```

### مثال 2: دعوة شركة
```
الداعي (Ahmed): role = 'doctor'
المدعو (MedPharma Co): role = 'company'

النقاط:
  - Ahmed (الداعي): +2 نقطة ✅ (لأن MedPharma شركة)
  - MedPharma (المدعو): +2 نقطة ✅
```

### مثال 3: دعوة موزع
```
الداعي (Hossam): role = 'doctor'
المدعو (Khaled): role = 'distributor'

النقاط:
  - Hossam (الداعي): +2 نقطة ✅ (لأن Khaled موزع)
  - Khaled (المدعو): +2 نقطة ✅
```

---

## التطبيق 🚀

### 1. رفع الدالة المحدثة إلى Supabase:

```bash
# في terminal
cd D:/fieldawy_store

# رفع الدالة المحدثة
supabase functions deploy handle-referral
```

### 2. اختبار النظام:

#### في التطبيق:
1. ✅ مستخدم جديد يدخل كود دعوة
2. ✅ افحص النقاط للداعي والمدعو
3. ✅ تأكد من النقاط الصحيحة حسب الـ role

#### في Supabase SQL Editor:
```sql
-- فحص النقاط الحالية
SELECT 
  id, 
  display_name, 
  role, 
  points 
FROM users 
WHERE id IN ('inviter-id', 'invited-id');

-- فحص سجل الدعوات
SELECT 
  r.*,
  u1.display_name AS inviter_name,
  u1.role AS inviter_role,
  u2.display_name AS invited_name,
  u2.role AS invited_role
FROM referrals r
JOIN users u1 ON r.inviter_id = u1.id
JOIN users u2 ON r.invited_id = u2.id
ORDER BY r.created_at DESC
LIMIT 10;
```

---

## الدوال المستخدمة 🔧

### `increment_user_points(user_id, points)`
```sql
-- موجودة في: supabase/migrations/20251025_add_increment_points_function.sql
CREATE OR REPLACE FUNCTION public.increment_user_points(
  user_id_param UUID, 
  points_to_add INT
)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET points = points + points_to_add
  WHERE id = user_id_param;
END;
$$ LANGUAGE plpgsql;
```

**لا حاجة لتعديلها** - تعمل كما هي ✅

---

## الأمان 🔒

### ما لم يتغير (آمن):
- ✅ جدول `referrals` - لم يُمس
- ✅ دالة `increment_user_points` - لم تُمس
- ✅ RLS policies - لم تُمس
- ✅ triggers - لم تُمس
- ✅ جدول `users` - لم يُمس

### ما تغير (آمن أيضاً):
- ✅ فقط منطق حساب النقاط في `handle-referral/index.ts`
- ✅ إضافة query لجلب role المدعو
- ✅ إضافة استدعاء إضافي لـ `increment_user_points` للمدعو

---

## التحقق 🧪

### قبل التطبيق:
```typescript
// الكود القديم
points_to_add: 1  // دائماً
```

### بعد التطبيق:
```typescript
// الكود الجديد
inviterPoints = (role === 'company' || role === 'distributor') ? 2 : 1
invitedPoints = 2  // دائماً
```

---

## السيناريوهات المحتملة 🎬

### سيناريو 1: role غير موجود
```typescript
const invitedRole = invitedUser?.role || 'doctor'; // ✅ default to doctor
```
**النتيجة**: الداعي يحصل على 1 نقطة (افتراضياً)

### سيناريو 2: خطأ في جلب role
```typescript
if (invitedUserError) {
  console.error(`Failed to get invited user role:`, invitedUserError);
}
```
**النتيجة**: يستمر التنفيذ مع القيمة الافتراضية (doctor)

### سيناريو 3: خطأ في إضافة النقاط
```typescript
if (inviterPointsError) {
  console.error(`Failed to award points...`);
}
```
**النتيجة**: يسجل الخطأ لكن لا يفشل الـ referral

---

## الملخص 📋

| العنصر | القيمة القديمة | القيمة الجديدة |
|--------|----------------|----------------|
| الداعي (طبيب مدعو) | 1 نقطة | 1 نقطة ✅ |
| الداعي (شركة/موزع مدعو) | 1 نقطة | 2 نقطة ✅ |
| المدعو | 0 نقطة | 2 نقطة ✅ |

---

## الخلاصة 🎉

- ✅ **آمن**: لا يؤثر على باقي النظام
- ✅ **بسيط**: تغيير منطق حساب النقاط فقط
- ✅ **قابل للاختبار**: يمكن التحقق بسهولة
- ✅ **مُوثق**: كل شيء موثق في هذا الملف

**جاهز للتطبيق!** 🚀
