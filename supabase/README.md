Supabase migration notes

- Add environment keys when running:
  flutter run --dart-define=SUPABASE_URL=your-url --dart-define=SUPABASE_ANON_KEY=your-anon-key

- Android OAuth redirect:
  Scheme: io.supabase.fieldawy
  Host: login-callback
  Make sure the redirectTo used in auth matches: io.supabase.fieldawy://login-callback/

- Apply schema:
  Run the SQL in supabase/schema.sql in your Supabase project (via SQL editor).

- Tables used by the app:
  users, products, distributor_products

