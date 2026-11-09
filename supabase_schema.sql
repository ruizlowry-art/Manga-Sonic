-- Supabase Database Schema for MangaSonic
-- Run this in your Supabase SQL Editor (Dashboard > SQL Editor)
-- 
-- This creates tables for:
-- 1. library_items - User's manga library
-- 2. reading_progress - User's reading progress per chapter
-- 3. categories - User's custom library categories (optional)
--
-- All tables have Row Level Security (RLS) policies to ensure users only access their own data.

-- Enable pgcrypto extension for gen_random_uuid() (usually enabled by default in Supabase)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- LIBRARY ITEMS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.library_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    manga_url TEXT NOT NULL,
    title TEXT NOT NULL,
    cover_url TEXT NOT NULL,
    source_id TEXT NOT NULL,
    category_id TEXT DEFAULT '',
    added_at BIGINT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure one library entry per manga per user
    UNIQUE(user_id, manga_url)
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_library_items_user_id ON public.library_items(user_id);
CREATE INDEX IF NOT EXISTS idx_library_items_updated_at ON public.library_items(updated_at);

-- Enable Row Level Security
ALTER TABLE public.library_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies for library_items
-- Users can only see their own library items
CREATE POLICY "Users can view own library items"
    ON public.library_items
    FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own library items
CREATE POLICY "Users can insert own library items"
    ON public.library_items
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own library items
CREATE POLICY "Users can update own library items"
    ON public.library_items
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own library items
CREATE POLICY "Users can delete own library items"
    ON public.library_items
    FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- READING PROGRESS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.reading_progress (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    chapter_url TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    last_page INTEGER DEFAULT 0,
    last_page_offset DOUBLE PRECISION DEFAULT 0.0,
    last_read_timestamp BIGINT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure one progress entry per chapter per user
    UNIQUE(user_id, chapter_url)
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_reading_progress_user_id ON public.reading_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_reading_progress_updated_at ON public.reading_progress(updated_at);

-- Enable Row Level Security
ALTER TABLE public.reading_progress ENABLE ROW LEVEL SECURITY;

-- RLS Policies for reading_progress
CREATE POLICY "Users can view own reading progress"
    ON public.reading_progress
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own reading progress"
    ON public.reading_progress
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own reading progress"
    ON public.reading_progress
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own reading progress"
    ON public.reading_progress
    FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- CATEGORIES TABLE (Optional - for custom categories)
-- ============================================
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_categories_user_id ON public.categories(user_id);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own categories"
    ON public.categories
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own categories"
    ON public.categories
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own categories"
    ON public.categories
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own categories"
    ON public.categories
    FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Function to get current user's library count
CREATE OR REPLACE FUNCTION public.get_library_count()
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT COUNT(*) FROM public.library_items WHERE user_id = auth.uid();
$$;

-- Function to get current user's reading progress count
CREATE OR REPLACE FUNCTION public.get_progress_count()
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT COUNT(*) FROM public.reading_progress WHERE user_id = auth.uid();
$$;

-- ============================================
-- REALTIME (Optional - for live sync across devices)
-- ============================================
-- Uncomment the following to enable realtime subscriptions
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.library_items;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.reading_progress;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.categories;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Run these to verify the setup:

-- Check tables exist
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

-- Check RLS is enabled
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';

-- Check policies
-- SELECT * FROM pg_policies WHERE schemaname = 'public';

-- Test insert (run as authenticated user):
-- INSERT INTO public.library_items (user_id, manga_url, title, cover_url, source_id, category_id, added_at)
-- VALUES (auth.uid(), 'test_url', 'Test Manga', 'cover_url', 'test_source', 'default', extract(epoch from now()) * 1000);