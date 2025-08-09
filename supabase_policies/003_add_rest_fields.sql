-- Adds a recommended rest time to exercises and per-workout custom values
-- for sets, reps and rest time. Run this in the Supabase SQL editor. Note
-- that the workout_exercises values are optional and default to the
-- recommended values when inserting via the app.

alter table public.exercises
  add column if not exists recommended_rest_seconds integer not null default 60;

alter table public.workout_exercises
  add column if not exists sets integer,
  add column if not exists reps integer,
  add column if not exists rest_seconds integer;