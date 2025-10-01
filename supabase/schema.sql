-- 🔹 Users table
create table if not exists public.users (
  uid uuid primary key, -- 🟢 بدل text → uuid
  display_name text,
  email text,
  photo_url text,
  role text check (role in ('viewer','doctor','distributor','company')) default 'viewer',
  account_status text check (account_status in ('pending_review','pending_re_review','approved','rejected')) default 'pending_review',
  is_profile_complete boolean default false,
  document_url text,
  whatsapp_number text,
  company_name text,
  is_verified boolean default false,
  governorates jsonb,
  centers jsonb,
  created_at timestamp with time zone default now()
);

alter table public.users enable row level security;

-- RLS: القراءة للمصادقين فقط
create policy users_select_authenticated
on public.users
for select
using (auth.role() = 'authenticated');

-- RLS: المستخدم يقدر يعمل insert لحسابه فقط
create policy users_insert_self
on public.users
for insert
with check (uid = auth.uid());

-- RLS: المستخدم يقدر يعمل update لحسابه فقط
create policy users_update_self
on public.users
for update
using (uid = auth.uid())
with check (uid = auth.uid());


-- 🔹 Products table
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  active_principle text,
  company text,
  action text,
  package text,
  image_url text,
  price numeric,
  distributor_id uuid references public.users(uid) on delete set null,
  created_at timestamp with time zone default now(),
  selected_package text
);

alter table public.products enable row level security;

-- RLS: القراءة متاحة للجميع
create policy products_select_all
on public.products
for select
using (true);

-- RLS: الكتابة فقط للمصادقين (ممكن تقيدها أكتر بـ role)
create policy products_write_authenticated
on public.products
for insert, update, delete
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');


-- 🔹 Distributor products table
create table if not exists public.distributor_products (
  id text primary key, -- `${distributor_id}_${product_id}_${package}`
  distributor_id uuid not null references public.users(uid) on delete cascade,
  distributor_name text,
  product_id uuid not null references public.products(id) on delete cascade,
  package text,
  price numeric,
  added_at timestamp with time zone default now()
);

create index if not exists idx_distributor_products_distributor on public.distributor_products(distributor_id);
create index if not exists idx_distributor_products_product on public.distributor_products(product_id);

alter table public.distributor_products enable row level security;

-- RLS: القراءة متاحة للمصادقين
create policy distributor_products_select
on public.distributor_products
for select
using (auth.role() = 'authenticated');

-- RLS: الموزع يقدر يكتب / يعدل / يحذف في سجلاته فقط
create policy distributor_products_owner_write
on public.distributor_products
for all
using (distributor_id = auth.uid())
with check (distributor_id = auth.uid());

-- 🔹 Function to complete user profile
create or replace function complete_user_profile(
  p_display_name text,
  p_whatsapp_number text,
  p_role text,
  p_document_url text,
  p_governorates jsonb,
  p_centers jsonb
)
returns void as $
begin
  update public.users
  set
    display_name = p_display_name,
    whatsapp_number = p_whatsapp_number,
    role = p_role,
    document_url = p_document_url,
    governorates = p_governorates,
    centers = p_centers,
    is_profile_complete = true
  where
    uid = auth.uid();
end;
$ language plpgsql;

-- 🔹 OCR Products table
create table if not exists public.ocr_products (
  id uuid primary key default gen_random_uuid(),
  distributor_id uuid null references public.users(uid),
  distributor_name text null,
  product_name text null,
  product_company text null,
  active_principle text null,
  package text null,
  created_at timestamp with time zone null default now(),
  image_url text null
);

alter table public.ocr_products enable row level security;

create policy "Enable read access for all users" on public.ocr_products
as permissive for select
to authenticated
using (true);

create policy "Enable insert for authenticated users only" on public.ocr_products
as permissive for insert
to authenticated
with check (true);


-- 🔹 Distributor OCR Products table
create table if not exists public.distributor_ocr_products (
  id uuid not null default gen_random_uuid (),
  distributor_id uuid not null,
  ocr_product_id uuid not null,
  distributor_name text null,
  price numeric null,
  created_at timestamp with time zone null default now(),
  constraint distributor_ocr_products_pkey primary key (id),
  constraint distributor_ocr_products_ocr_product_id_fkey foreign KEY (ocr_product_id) references ocr_products (id) on delete CASCADE
);

alter table public.distributor_ocr_products enable row level security;

create policy "Enable read access for all users" on public.distributor_ocr_products
as permissive for select
to authenticated
using (true);

create policy "Enable insert for users based on user_id" on public.distributor_ocr_products
as permissive for insert
to authenticated
with check (auth.uid() = distributor_id);

create policy "Enable update for users based on user_id" on public.distributor_ocr_products
as permissive for update
to authenticated
using (auth.uid() = distributor_id)
with check (auth.uid() = distributor_id);

create policy "Enable delete for users based on user_id" on public.distributor_ocr_products
as permissive for delete
to authenticated
using (auth.uid() = distributor_id);
