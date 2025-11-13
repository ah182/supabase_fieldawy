-- التحقق من عمود المحافظات في جدول users

-- 1. عرض أسماء الأعمدة في جدول users
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users'
ORDER BY ordinal_position;

-- 2. عرض عينة من البيانات (أول 10 users مع المحافظات)
SELECT id, name, governorate, governorates
FROM users
WHERE governorate IS NOT NULL OR governorates IS NOT NULL
LIMIT 10;

-- 3. عرض كل القيم الفريدة للمحافظات
SELECT DISTINCT governorate as governorate_value, COUNT(*) as user_count
FROM users
WHERE governorate IS NOT NULL
GROUP BY governorate
ORDER BY user_count DESC;

-- أو إذا كان العمود governorates:
SELECT DISTINCT governorates as governorate_value, COUNT(*) as user_count
FROM users
WHERE governorates IS NOT NULL
GROUP BY governorates
ORDER BY user_count DESC;

-- 4. البحث عن أي عمود يحتوي على كلمة "محافظة" أو "govern"
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'users' 
  AND (column_name LIKE '%govern%' OR column_name LIKE '%محافظ%');
