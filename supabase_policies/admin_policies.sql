-- Admin and role-based policies for armwrestling app

-- Create profiles table to store role and ban status
create table if not exists public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    role text not null default 'user',
    is_banned boolean not null default false,
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone default now()
);

-- Trigger to update updated_at
create or replace function public.update_timestamp_profiles()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists update_timestamp_profiles on public.profiles;

create trigger update_timestamp_profiles
before update on public.profiles
for each row
execute procedure public.update_timestamp_profiles();

-- Trigger to insert profile when a new auth.user is created
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute procedure public.handle_new_user();

-- Helper functions to check admin and ban status
create or replace function public.is_admin()
returns boolean
language sql stable
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  );
$$;

create or replace function public.is_not_banned()
returns boolean
language sql stable
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_banned = false
  );
$$;

-- Enable RLS and define policies

-- profiles table
alter table public.profiles enable row level security;

-- Users can see and update their own profiles; admins can access all
create policy "Profiles: Select own or admin" on public.profiles
  for select using (public.is_admin() or id = auth.uid());

create policy "Profiles: Update own or admin" on public.profiles
  for update using (public.is_admin() or id = auth.uid());

create policy "Profiles: Insert" on public.profiles
  for insert with check (true);

-- categories table
alter table public.categories enable row level security;

create policy "Categories: Read" on public.categories
  for select using (public.is_not_banned());

create policy "Categories: Admin all" on public.categories
  for all using (public.is_admin());

-- exercises table
alter table public.exercises enable row level security;

create policy "Exercises: Read" on public.exercises
  for select using (public.is_not_banned());

create policy "Exercises: Admin all" on public.exercises
  for all using (public.is_admin());

-- videos table
alter table public.videos enable row level security;

create policy "Videos: Read" on public.videos
  for select using (public.is_not_banned());

create policy "Videos: Admin all" on public.videos
  for all using (public.is_admin());

-- workouts table
alter table public.workouts enable row level security;

create policy "Workouts: Read" on public.workouts
  for select using (
    public.is_not_banned() and (
      public.is_admin() or is_public = true or user_id = auth.uid()
    )
  );

create policy "Workouts: Insert" on public.workouts
  for insert with check (
    public.is_admin() or user_id = auth.uid()
  );

create policy "Workouts: Update" on public.workouts
  for update using (
    public.is_admin() or user_id = auth.uid()
  );

create policy "Workouts: Delete" on public.workouts
  for delete using (
    public.is_admin() or user_id = auth.uid()
  );

-- workout_exercises table
alter table public.workout_exercises enable row level security;

create policy "WorkoutExercises: Read" on public.workout_exercises
  for select using (
    public.is_not_banned() and (
      public.is_admin() or exists (
        select 1 from public.workouts w
        where w.id = workout_exercises.workout_id
          and (w.user_id = auth.uid() or w.is_public = true)
      )
    )
  );

create policy "WorkoutExercises: Insert" on public.workout_exercises
  for insert with check (
    public.is_admin() or exists (
      select 1 from public.workouts w
      where w.id = workout_id and w.user_id = auth.uid()
    )
  );

create policy "WorkoutExercises: Update" on public.workout_exercises
  for update using (
    public.is_admin() or exists (
      select 1 from public.workouts w
      where w.id = workout_exercises.workout_id and w.user_id = auth.uid()
    )
  );

create policy "WorkoutExercises: Delete" on public.workout_exercises
  for delete using (
    public.is_admin() or exists (
      select 1 from public.workouts w
      where w.id = workout_exercises.workout_id and w.user_id = auth.uid()
    )
  );

-- exercise_categories table
alter table public.exercise_categories enable row level security;

create policy "ExerciseCategories: Read" on public.exercise_categories
  for select using (public.is_not_banned());

create policy "ExerciseCategories: Admin all" on public.exercise_categories
  for all using (public.is_admin());

-- video_categories table
alter table public.video_categories enable row level security;

create policy "VideoCategories: Read" on public.video_categories
  for select using (public.is_not_banned());

create policy "VideoCategories: Admin all" on public.video_categories
  for all using (public.is_admin());

-- exercise_videos table
alter table public.exercise_videos enable row level security;

create policy "ExerciseVideos: Read" on public.exercise_videos
  for select using (public.is_not_banned());

create policy "ExerciseVideos: Admin all" on public.exercise_videos
  for all using (public.is_admin());