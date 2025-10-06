# الحذف التلقائي للعروض المنتهية

## النظام المطبق

تم تطبيق نظام حذف تلقائي للعروض المنتهية بحيث:

1. **الحذف التلقائي**: يتم حذف العروض تلقائياً بعد **7 أيام** من انتهاء صلاحيتها
2. **عرض المدة المتبقية**: تظهر في واجهة كل عرض:
   - للعروض السارية: "متبقي X أيام"
   - للعروض المنتهية: "يُحذف خلال X أيام"

## كيفية العمل

### 1. الحذف من جانب التطبيق (Client-side)
يتم حذف العروض المنتهية تلقائياً عند:
- فتح شاشة العروض المحدودة
- تحديث قائمة العروض

الكود موجود في: `lib/features/products/data/product_repository.dart`

```dart
Future<void> deleteExpiredOffers() async {
  final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
  await _supabase
      .from('offers')
      .delete()
      .lt('expiration_date', sevenDaysAgo.toIso8601String());
}
```

### 2. الحذف من جانب الخادم (Server-side) - اختياري

لتفعيل الحذف التلقائي الكامل من جانب الخادم:

#### الخيار 1: استخدام Supabase Edge Functions (موصى به)

1. قم برفع الـ Edge Function:
```bash
supabase functions deploy delete-expired-offers
```

2. قم بجدولة الوظيفة للتشغيل يومياً:
   - افتح Supabase Dashboard
   - اذهب إلى **Database > Cron Jobs**
   - أضف Cron Job جديد:
     - **Schedule**: `0 0 * * *` (كل يوم في منتصف الليل)
     - **Command**:
     ```sql
     select net.http_post(
       url:='https://YOUR_PROJECT_REF.supabase.co/functions/v1/delete-expired-offers',
       headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb
     );
     ```

#### الخيار 2: استخدام Database Function مباشرة

قم بتشغيل الـ SQL التالي في Supabase SQL Editor:

```sql
-- إنشاء الوظيفة
CREATE OR REPLACE FUNCTION delete_expired_offers()
RETURNS void AS $$
BEGIN
  DELETE FROM offers
  WHERE expiration_date < (NOW() - INTERVAL '7 days');
END;
$$ LANGUAGE plpgsql;

-- جدولة تشغيلها يومياً
SELECT cron.schedule(
  'delete-expired-offers',
  '0 0 * * *',
  'SELECT delete_expired_offers();'
);
```

**ملاحظة**: قد تحتاج إلى تفعيل `pg_cron` extension أولاً:
```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;
```

## الملفات المعدلة

1. `lib/features/products/presentation/screens/limited_offer_screen.dart`
   - إضافة عرض المدة المتبقية لكل عرض
   - عرض تحذير للعروض المنتهية مع موعد الحذف

2. `lib/features/products/data/product_repository.dart`
   - إضافة دالة `deleteExpiredOffers()`
   - استدعاء الدالة عند جلب قائمة العروض

3. `supabase/migrations/auto_delete_expired_offers.sql`
   - SQL script للحذف التلقائي من جانب الخادم

4. `supabase/functions/delete-expired-offers/index.ts`
   - Edge Function للحذف التلقائي

## الاختبار

لاختبار النظام:

1. أضف عرضاً بتاريخ صلاحية منتهي
2. انتظر أكثر من 7 أيام (أو عدّل التاريخ في الكود للاختبار)
3. افتح شاشة العروض المحدودة
4. يجب أن يتم حذف العرض المنتهي تلقائياً

## ملاحظات

- الحذف من جانب التطبيق يعمل فوراً دون الحاجة لإعدادات إضافية
- الحذف من جانب الخادم اختياري ولكن موصى به للحفاظ على قاعدة البيانات نظيفة
- المدة المحددة حالياً هي **7 أيام** بعد انتهاء الصلاحية
- يمكن تعديل المدة بتغيير `Duration(days: 7)` في الكود
