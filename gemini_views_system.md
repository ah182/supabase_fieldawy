انا عامل فيو سيستم ولكن مش شغال كويس عايزك تعملي فيو سيستم محكم في المنتجات الي في تابات الهوم اسكرين كاملة
هقولك علي الجداول و انت تحدد نوع المنتج و علي اساسة تزود المشاهدت لهذا المنتج 
1- regular
  create table public.distributor_products (
  id text not null,
  distributor_id uuid null,
  distributor_name text null,
  product_id text null,
  package text null,
  price numeric null,
  added_at timestamp with time zone null default now(),
  old_price numeric null,
  price_updated_at timestamp with time zone null,
  expiration_date date null,
  views integer null default 0,
  constraint distributor_products_pkey primary key (id),
  constraint distributor_products_distributor_id_fkey foreign KEY (distributor_id) references users (id) on update CASCADE on delete CASCADE,
  constraint distributor_products_product_id_fkey foreign KEY (product_id) references products (id) on delete CASCADE,
  constraint check_views_non_negative check ((views >= 0))
) TABLESPACE pg_default;

create index IF not exists idx_dp_product on public.distributor_products using btree (product_id) TABLESPACE pg_default;

create index IF not exists idx_dp_distributor on public.distributor_products using btree (distributor_id) TABLESPACE pg_default;

create index IF not exists idx_distributor_products_expiration on public.distributor_products using btree (expiration_date) TABLESPACE pg_default
where
  (expiration_date is not null);

create index IF not exists idx_distributor_products_price_updated on public.distributor_products using btree (price_updated_at desc) TABLESPACE pg_default
where
  (price_updated_at is not null);

create index IF not exists idx_distributor_products_views on public.distributor_products using btree (views desc) TABLESPACE pg_default;

create trigger distributorproducts
after INSERT
or
update on distributor_products for EACH row
execute FUNCTION supabase_functions.http_request (
  'https://notification-webhook.ah3181997-1e7.workers.dev',
  'POST',
  '{"Content-type":"application/json"}',
  '{}',
  '5000'
);

create trigger trigger_notify_distributor_products
after INSERT
or
update on distributor_products for EACH row
execute FUNCTION notify_product_change ();

create trigger trigger_track_price_change BEFORE
update on distributor_products for EACH row
execute FUNCTION update_distributor_products_price_tracking ();

create trigger update_product_views_trigger
after INSERT
or DELETE
or
update on distributor_products for EACH row
execute FUNCTION trigger_update_product_views ();

2- ocr 
create table public.distributor_ocr_products (
  id uuid not null default gen_random_uuid (),
  distributor_id uuid not null,
  ocr_product_id uuid not null,
  distributor_name text null,
  price numeric null,
  created_at timestamp with time zone null default now(),
  expiration_date date null,
  old_price numeric null,
  price_updated_at timestamp with time zone null,
  views integer null default 0,
  constraint distributor_ocr_products_pkey primary key (id),
  constraint distributor_ocr_products_ocr_product_id_fkey foreign KEY (ocr_product_id) references ocr_products (id) on delete CASCADE,
  constraint check_ocr_views_non_negative check ((views >= 0))
) TABLESPACE pg_default;

create index IF not exists idx_ocr_products_views on public.distributor_ocr_products using btree (views desc) TABLESPACE pg_default;

create index IF not exists idx_distributor_ocr_products_views on public.distributor_ocr_products using btree (views desc) TABLESPACE pg_default;

create trigger distributorocrproducts
after INSERT
or
update on distributor_ocr_products for EACH row
execute FUNCTION supabase_functions.http_request (
  'https://notification-webhook.ah3181997-1e7.workers.dev',
  'POST',
  '{"Content-type":"application/json"}',
  '{}',
  '5000'
);

create trigger trigger_notify_distributor_ocr_products
after INSERT
or
update on distributor_ocr_products for EACH row
execute FUNCTION notify_product_change ();

create trigger update_ocr_product_views_trigger
after INSERT
or DELETE
or
update on distributor_ocr_products for EACH row
execute FUNCTION trigger_update_ocr_product_views ();

3- surgical 
create table public.distributor_surgical_tools (
  id uuid not null default gen_random_uuid (),
  distributor_id uuid not null,
  distributor_name text not null,
  surgical_tool_id uuid not null,
  description text not null,
  price numeric(12, 2) not null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  status text null default 'جديد'::text,
  views integer null default 0,
  comments_count integer null default 0,
  constraint distributor_surgical_tools_pkey primary key (id),
  constraint distributor_surgical_tools_distributor_id_surgical_tool_id_key unique (distributor_id, surgical_tool_id),
  constraint distributor_surgical_tools_distributor_id_fkey foreign KEY (distributor_id) references auth.users (id) on delete CASCADE,
  constraint distributor_surgical_tools_surgical_tool_id_fkey foreign KEY (surgical_tool_id) references surgical_tools (id) on delete CASCADE,
  constraint check_surgical_views_non_negative check ((views >= 0)),
  constraint distributor_surgical_tools_price_check check ((price >= (0)::numeric))
) TABLESPACE pg_default;

create index IF not exists idx_surgical_tools_views on public.distributor_surgical_tools using btree (views desc) TABLESPACE pg_default;

create index IF not exists idx_distributor_surgical_tools_views on public.distributor_surgical_tools using btree (views desc) TABLESPACE pg_default;

create trigger distributorsurgicaltools
after INSERT
or
update on distributor_surgical_tools for EACH row
execute FUNCTION supabase_functions.http_request (
  'https://notification-webhook.ah3181997-1e7.workers.dev',
  'POST',
  '{"Content-type":"application/json"}',
  '{}',
  '5000'
);

create trigger trigger_notify_distributor_surgical_tools
after INSERT
or
update on distributor_surgical_tools for EACH row
execute FUNCTION notify_product_change ();

create trigger update_surgical_tool_views_trigger
after INSERT
or DELETE
or
update on distributor_surgical_tools for EACH row
execute FUNCTION trigger_update_surgical_tool_views ();
 

 اعمل سيستم محكم ل التلاتة دول كدة لو اشتغل هنكمل باقي التابات 
 اعمل سيستم فيو كانك اول مرة متلتزمش بالفانكشن الموجودة 
 اقرا صفحة البرودكت كارد عشان تفهم المشاهدات بتتم ازاي 
 يلا انطلق و اشرحلي خطوة بخطوة قبل التنفيذ 