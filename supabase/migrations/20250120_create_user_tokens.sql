-- إنشاء جدول user_tokens لحفظ FCM tokens
create table if not exists user_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  token text not null unique,
  device_type text,
  device_name text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- إنشاء index لتسريع البحث
create index if not exists idx_user_tokens_user_id on user_tokens(user_id);
create index if not exists idx_user_tokens_token on user_tokens(token);

-- إنشاء function لتحديث updated_at تلقائياً
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- إنشاء trigger لتحديث updated_at عند التعديل
create trigger update_user_tokens_updated_at
  before update on user_tokens
  for each row
  execute function update_updated_at_column();

-- إضافة RLS (Row Level Security)
alter table user_tokens enable row level security;

-- سياسة: المستخدم يمكنه قراءة tokens الخاصة به فقط
create policy "Users can read their own tokens"
  on user_tokens
  for select
  using (auth.uid() = user_id);

-- سياسة: المستخدم يمكنه إضافة tokens جديدة
create policy "Users can insert their own tokens"
  on user_tokens
  for insert
  with check (auth.uid() = user_id);

-- سياسة: المستخدم يمكنه تحديث tokens الخاصة به
create policy "Users can update their own tokens"
  on user_tokens
  for update
  using (auth.uid() = user_id);

-- سياسة: المستخدم يمكنه حذف tokens الخاصة به
create policy "Users can delete their own tokens"
  on user_tokens
  for delete
  using (auth.uid() = user_id);

-- دالة لإضافة أو تحديث token (upsert)
create or replace function upsert_user_token(
  p_user_id uuid,
  p_token text,
  p_device_type text default null,
  p_device_name text default null
)
returns void as $$
begin
  insert into user_tokens (user_id, token, device_type, device_name)
  values (p_user_id, p_token, p_device_type, p_device_name)
  on conflict (token)
  do update set
    user_id = excluded.user_id,
    device_type = excluded.device_type,
    device_name = excluded.device_name,
    updated_at = now();
end;
$$ language plpgsql security definer;

-- دالة للحصول على جميع tokens (للاستخدام من Backend)
create or replace function get_all_active_tokens()
returns table (
  token text,
  user_id uuid,
  device_type text
) as $$
begin
  return query
  select ut.token, ut.user_id, ut.device_type
  from user_tokens ut
  where ut.created_at > now() - interval '90 days'; -- tokens نشطة خلال 90 يوم
end;
$$ language plpgsql security definer;

-- دالة للحصول على tokens مستخدم محدد
create or replace function get_user_tokens(p_user_id uuid)
returns table (
  token text,
  device_type text,
  device_name text,
  created_at timestamp with time zone
) as $$
begin
  return query
  select ut.token, ut.device_type, ut.device_name, ut.created_at
  from user_tokens ut
  where ut.user_id = p_user_id
  order by ut.created_at desc;
end;
$$ language plpgsql security definer;

-- تنظيف tokens القديمة (يمكن تشغيلها بـ cron)
create or replace function cleanup_old_tokens()
returns void as $$
begin
  delete from user_tokens
  where created_at < now() - interval '180 days';
end;
$$ language plpgsql security definer;

-- تعليق على الجدول
comment on table user_tokens is 'جدول لحفظ FCM tokens للمستخدمين';
comment on column user_tokens.token is 'FCM Token الفريد للجهاز';
comment on column user_tokens.device_type is 'نوع الجهاز (Android, iOS, Web)';
comment on column user_tokens.device_name is 'اسم الجهاز أو الموديل';
