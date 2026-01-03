-- 1. التأكد من تفعيل إضافة pg_cron (تعمل عادةً على مشاريع Supabase Pro، وقد لا تعمل على الـ Free Tier القديم)
-- إذا كنت تستخدم Free Tier ولا تدعم pg_cron، ستحتاج لاستخدام Edge Function.
create extension if not exists pg_cron;

-- 2. إنشاء دالة الحذف
create or replace function public.delete_expired_stories()
returns void
language plpgsql
security definer
as $$
begin
  -- حذف الصفوف التي وقت انتهائها أقل من الوقت الحالي
  delete from public.distributor_stories
  where expires_at < now();
end;
$$;

-- 3. جدولة المهمة لتعمل كل ساعة
-- التنسيق: 'دقيقة ساعة يوم شهر يوم_أسبوع'
-- '0 * * * *' تعني عند الدقيقة صفر من كل ساعة
select cron.schedule(
  'cleanup-expired-stories', -- اسم المهمة
  '0 * * * *',              -- التوقيت (كل ساعة)
  'select public.delete_expired_stories()'
);

-- لعرض الوظائف المجدولة للتأكد:
-- select * from cron.job;
