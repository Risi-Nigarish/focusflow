-- FocusFlow Supabase Setup & Security Configuration Script
-- Copy and run this script in your Supabase SQL Editor (https://supabase.com/dashboard/project/_/sql)

-- 1. Enable UUID extension for auto-generating unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Create tasks table
CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    due_date TIMESTAMP WITH TIME ZONE,
    priority TEXT DEFAULT 'medium',
    category TEXT DEFAULT 'Personal',
    tags TEXT[] DEFAULT '{}',
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    reminders TIMESTAMP WITH TIME ZONE[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Create categories table
CREATE TABLE IF NOT EXISTS public.categories (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    color BIGINT NOT NULL,
    PRIMARY KEY (user_id, name)
);

-- 4. Enable Row Level Security (RLS) on both tables (Crucial for data security)
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- 5. Row Level Security Policies for 'tasks' Table
-- Enforce that users can only select/view their own tasks
CREATE POLICY "Users can only view their own tasks" 
ON public.tasks FOR SELECT 
USING (auth.uid() = user_id);

-- Enforce that users can only insert tasks with their own user_id
CREATE POLICY "Users can only insert their own tasks" 
ON public.tasks FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Enforce that users can only update tasks belonging to them
CREATE POLICY "Users can only update their own tasks" 
ON public.tasks FOR UPDATE 
USING (auth.uid() = user_id);

-- Enforce that users can only delete tasks belonging to them
CREATE POLICY "Users can only delete their own tasks" 
ON public.tasks FOR DELETE 
USING (auth.uid() = user_id);

-- 6. Row Level Security Policies for 'categories' Table
-- Enforce that users can only select/view their own custom categories
CREATE POLICY "Users can only view their own categories" 
ON public.categories FOR SELECT 
USING (auth.uid() = user_id);

-- Enforce that users can only insert custom categories with their own user_id
CREATE POLICY "Users can only insert their own categories" 
ON public.categories FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Enforce that users can only update custom categories belonging to them
CREATE POLICY "Users can only update their own categories" 
ON public.categories FOR UPDATE 
USING (auth.uid() = user_id);

-- Enforce that users can only delete custom categories belonging to them
CREATE POLICY "Users can only delete their own categories" 
ON public.categories FOR DELETE 
USING (auth.uid() = user_id);

-- 7. Performance Optimization Indexes
-- Indexes speed up queries when filtering by user_id
CREATE INDEX IF NOT EXISTS tasks_user_id_idx ON public.tasks(user_id);
CREATE INDEX IF NOT EXISTS categories_user_id_idx ON public.categories(user_id);

-- 8. Schema Updates (Migration support for existing tables)
-- Adds the completed_at column to tasks table if it doesn't already exist
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE;

