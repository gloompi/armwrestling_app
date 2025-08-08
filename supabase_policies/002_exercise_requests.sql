-- Migration script to create the exercise_requests table and row level
-- security policies. This table stores user-submitted requests for new
-- exercises. Users can submit a request with optional preview and video
-- URLs as well as recommended sets and reps. Only admins are allowed
-- to view, update or delete requests. Regular users may insert new
-- requests for themselves, but cannot see or edit existing requests.

-- Create table if it does not exist
create table if not exists public.exercise_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null,
  description text,
  preview_url text,
  video_urls text[],
  recommended_sets integer,
  recommended_reps integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Enable row level security on the table
alter table public.exercise_requests enable row level security;

-- Policy allowing authenticated users to insert requests for themselves.
create policy "exercise_requests_insert_own" on public.exercise_requests
  for insert
  with check (auth.uid() = user_id);

-- Policy allowing admins to view all requests. Assumes a `profiles` table
-- with a `role` column where admins have role = 'admin'. If such a table
-- does not exist, replace the condition with `auth.role() = 'service_role'`
-- or similar.
create policy "exercise_requests_select_admin" on public.exercise_requests
  for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );

-- Policy allowing admins to update any request.
create policy "exercise_requests_update_admin" on public.exercise_requests
  for update
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );

-- Policy allowing admins to delete any request.
create policy "exercise_requests_delete_admin" on public.exercise_requests
  for delete
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );