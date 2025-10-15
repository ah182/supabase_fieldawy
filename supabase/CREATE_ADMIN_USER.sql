-- ═══════════════════════════════════════════════════════════════
-- إنشاء حساب Admin - نسخة مصلحة
-- CREATE ADMIN USER - Fixed Version
-- ═══════════════════════════════════════════════════════════════

-- إنشاء حساب Admin جديد (بدون user_type)
DO $$
DECLARE
  admin_email TEXT := 'admin@fieldawy.com';  -- ⚠️ غير هذا لبريدك!
  admin_password TEXT := 'Admin@123456';     -- ⚠️ غير هذا لباسورد قوي!
  admin_name TEXT := 'Admin';
  new_user_id UUID;
BEGIN
  -- 1. إنشاء مستخدم في auth.users
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    admin_email,
    crypt(admin_password, gen_salt('bf')),
    NOW(),
    NOW(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('display_name', admin_name),
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
  ) RETURNING id INTO new_user_id;

  -- 2. إضافة المستخدم لجدول users مع role = admin
  INSERT INTO public.users (
    id,
    email,
    display_name,
    role,
    account_status,
    is_profile_complete,
    created_at
  ) VALUES (
    new_user_id,
    admin_email,
    admin_name,
    'admin',
    'approved',
    true,
    NOW()
  );

  RAISE NOTICE '✅ Admin created successfully: % (ID: %)', admin_email, new_user_id;
  
EXCEPTION
  WHEN unique_violation THEN
    RAISE NOTICE '⚠️ User already exists: %', admin_email;
  WHEN OTHERS THEN
    RAISE EXCEPTION '❌ Error creating admin: %', SQLERRM;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- التحقق من النجاح
-- ═══════════════════════════════════════════════════════════════

SELECT 
    id, 
    email, 
    display_name, 
    role, 
    account_status,
    created_at,
    '✅ Admin User Created!' as status
FROM public.users 
WHERE role = 'admin'
ORDER BY created_at DESC;

-- ═══════════════════════════════════════════════════════════════
-- معلومات مهمة
-- ═══════════════════════════════════════════════════════════════

-- احفظ هذه البيانات:
-- Email: admin@fieldawy.com
-- Password: Admin@123456

-- ═══════════════════════════════════════════════════════════════
