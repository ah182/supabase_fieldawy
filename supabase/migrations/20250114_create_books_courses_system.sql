-- ===================================================================
-- Books and Courses System Migration
-- ===================================================================
-- This migration creates tables and functions for veterinary books and courses

-- ===================================================================
-- 1. Create vet_books table
-- ===================================================================
CREATE TABLE IF NOT EXISTS public.vet_books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (char_length(name) >= 2 AND char_length(name) <= 200),
    author TEXT NOT NULL CHECK (char_length(author) >= 2 AND char_length(author) <= 100),
    description TEXT NOT NULL CHECK (char_length(description) >= 20 AND char_length(description) <= 1000),
    price DECIMAL(10, 2) NOT NULL CHECK (price > 0),
    phone TEXT NOT NULL CHECK (phone ~ '^\+[1-9]\d{1,14}$'), -- E.164 format
    image_url TEXT NOT NULL,
    views INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_vet_books_user_id ON public.vet_books(user_id);
CREATE INDEX IF NOT EXISTS idx_vet_books_created_at ON public.vet_books(created_at DESC);

-- ===================================================================
-- 2. Create vet_courses table
-- ===================================================================
CREATE TABLE IF NOT EXISTS public.vet_courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL CHECK (char_length(title) >= 5 AND char_length(title) <= 200),
    description TEXT NOT NULL CHECK (char_length(description) >= 20 AND char_length(description) <= 1000),
    price DECIMAL(10, 2) NOT NULL CHECK (price > 0),
    phone TEXT NOT NULL CHECK (phone ~ '^\+[1-9]\d{1,14}$'), -- E.164 format
    image_url TEXT NOT NULL,
    views INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_vet_courses_user_id ON public.vet_courses(user_id);
CREATE INDEX IF NOT EXISTS idx_vet_courses_created_at ON public.vet_courses(created_at DESC);

-- ===================================================================
-- 3. Enable Row Level Security (RLS)
-- ===================================================================
ALTER TABLE public.vet_books ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vet_courses ENABLE ROW LEVEL SECURITY;

-- ===================================================================
-- 4. RLS Policies for vet_books
-- ===================================================================

-- Allow anyone to view all books
CREATE POLICY "Anyone can view books"
ON public.vet_books FOR SELECT
USING (true);

-- Allow authenticated users to insert their own books
CREATE POLICY "Users can insert their own books"
ON public.vet_books FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own books
CREATE POLICY "Users can update their own books"
ON public.vet_books FOR UPDATE
USING (auth.uid() = user_id);

-- Allow users to delete their own books
CREATE POLICY "Users can delete their own books"
ON public.vet_books FOR DELETE
USING (auth.uid() = user_id);

-- ===================================================================
-- 5. RLS Policies for vet_courses
-- ===================================================================

-- Allow anyone to view all courses
CREATE POLICY "Anyone can view courses"
ON public.vet_courses FOR SELECT
USING (true);

-- Allow authenticated users to insert their own courses
CREATE POLICY "Users can insert their own courses"
ON public.vet_courses FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own courses
CREATE POLICY "Users can update their own courses"
ON public.vet_courses FOR UPDATE
USING (auth.uid() = user_id);

-- Allow users to delete their own courses
CREATE POLICY "Users can delete their own courses"
ON public.vet_courses FOR DELETE
USING (auth.uid() = user_id);

-- ===================================================================
-- 6. Helper Functions for Books
-- ===================================================================

-- Function to get all books with user information
CREATE OR REPLACE FUNCTION get_all_books()
RETURNS TABLE (
    id UUID,
    user_id UUID,
    name TEXT,
    author TEXT,
    description TEXT,
    price DECIMAL,
    phone TEXT,
    image_url TEXT,
    views INT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    user_name TEXT,
    user_role TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id,
        b.user_id,
        b.name,
        b.author,
        b.description,
        b.price,
        b.phone,
        b.image_url,
        b.views,
        b.created_at,
        b.updated_at,
        u.display_name AS user_name,
        u.role AS user_role
    FROM public.vet_books b
    LEFT JOIN public.users u ON b.user_id = u.id
    ORDER BY b.created_at DESC;
END;
$$;

-- Function to get user's own books
CREATE OR REPLACE FUNCTION get_my_books()
RETURNS TABLE (
    id UUID,
    user_id UUID,
    name TEXT,
    author TEXT,
    description TEXT,
    price DECIMAL,
    phone TEXT,
    image_url TEXT,
    views INT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id,
        b.user_id,
        b.name,
        b.author,
        b.description,
        b.price,
        b.phone,
        b.image_url,
        b.views,
        b.created_at,
        b.updated_at
    FROM public.vet_books b
    WHERE b.user_id = auth.uid()
    ORDER BY b.created_at DESC;
END;
$$;

-- Function to create a new book
CREATE OR REPLACE FUNCTION create_book(
    p_name TEXT,
    p_author TEXT,
    p_description TEXT,
    p_price DECIMAL,
    p_phone TEXT,
    p_image_url TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_book_id UUID;
BEGIN
    INSERT INTO public.vet_books (
        user_id, name, author, description, price, phone, image_url
    ) VALUES (
        auth.uid(), p_name, p_author, p_description, p_price, p_phone, p_image_url
    ) RETURNING id INTO new_book_id;
    
    RETURN new_book_id;
END;
$$;

-- Function to update a book
CREATE OR REPLACE FUNCTION update_book(
    p_book_id UUID,
    p_name TEXT,
    p_author TEXT,
    p_description TEXT,
    p_price DECIMAL,
    p_phone TEXT,
    p_image_url TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.vet_books
    SET 
        name = p_name,
        author = p_author,
        description = p_description,
        price = p_price,
        phone = p_phone,
        image_url = p_image_url,
        updated_at = NOW()
    WHERE id = p_book_id AND user_id = auth.uid();
    
    RETURN FOUND;
END;
$$;

-- Function to delete a book
CREATE OR REPLACE FUNCTION delete_book(p_book_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.vet_books
    WHERE id = p_book_id AND user_id = auth.uid();
    
    RETURN FOUND;
END;
$$;

-- Function to increment book views
CREATE OR REPLACE FUNCTION increment_book_views(p_book_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.vet_books
    SET views = views + 1
    WHERE id = p_book_id;
END;
$$;

-- ===================================================================
-- 7. Helper Functions for Courses
-- ===================================================================

-- Function to get all courses with user information
CREATE OR REPLACE FUNCTION get_all_courses()
RETURNS TABLE (
    id UUID,
    user_id UUID,
    title TEXT,
    description TEXT,
    price DECIMAL,
    phone TEXT,
    image_url TEXT,
    views INT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    user_name TEXT,
    user_role TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.user_id,
        c.title,
        c.description,
        c.price,
        c.phone,
        c.image_url,
        c.views,
        c.created_at,
        c.updated_at,
        u.display_name AS user_name,
        u.role AS user_role
    FROM public.vet_courses c
    LEFT JOIN public.users u ON c.user_id = u.id
    ORDER BY c.created_at DESC;
END;
$$;

-- Function to get user's own courses
CREATE OR REPLACE FUNCTION get_my_courses()
RETURNS TABLE (
    id UUID,
    user_id UUID,
    title TEXT,
    description TEXT,
    price DECIMAL,
    phone TEXT,
    image_url TEXT,
    views INT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.user_id,
        c.title,
        c.description,
        c.price,
        c.phone,
        c.image_url,
        c.views,
        c.created_at,
        c.updated_at
    FROM public.vet_courses c
    WHERE c.user_id = auth.uid()
    ORDER BY c.created_at DESC;
END;
$$;

-- Function to create a new course
CREATE OR REPLACE FUNCTION create_course(
    p_title TEXT,
    p_description TEXT,
    p_price DECIMAL,
    p_phone TEXT,
    p_image_url TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_course_id UUID;
BEGIN
    INSERT INTO public.vet_courses (
        user_id, title, description, price, phone, image_url
    ) VALUES (
        auth.uid(), p_title, p_description, p_price, p_phone, p_image_url
    ) RETURNING id INTO new_course_id;
    
    RETURN new_course_id;
END;
$$;

-- Function to update a course
CREATE OR REPLACE FUNCTION update_course(
    p_course_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_price DECIMAL,
    p_phone TEXT,
    p_image_url TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.vet_courses
    SET 
        title = p_title,
        description = p_description,
        price = p_price,
        phone = p_phone,
        image_url = p_image_url,
        updated_at = NOW()
    WHERE id = p_course_id AND user_id = auth.uid();
    
    RETURN FOUND;
END;
$$;

-- Function to delete a course
CREATE OR REPLACE FUNCTION delete_course(p_course_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.vet_courses
    WHERE id = p_course_id AND user_id = auth.uid();
    
    RETURN FOUND;
END;
$$;

-- Function to increment course views
CREATE OR REPLACE FUNCTION increment_course_views(p_course_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.vet_courses
    SET views = views + 1
    WHERE id = p_course_id;
END;
$$;

-- ===================================================================
-- 8. Grant permissions
-- ===================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vet_books TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vet_courses TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_books() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_my_books() TO authenticated;
GRANT EXECUTE ON FUNCTION create_book TO authenticated;
GRANT EXECUTE ON FUNCTION update_book TO authenticated;
GRANT EXECUTE ON FUNCTION delete_book TO authenticated;
GRANT EXECUTE ON FUNCTION increment_book_views TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_all_courses() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_my_courses() TO authenticated;
GRANT EXECUTE ON FUNCTION create_course TO authenticated;
GRANT EXECUTE ON FUNCTION update_course TO authenticated;
GRANT EXECUTE ON FUNCTION delete_course TO authenticated;
GRANT EXECUTE ON FUNCTION increment_course_views TO authenticated, anon;

-- ===================================================================
-- Migration Complete
-- ===================================================================
