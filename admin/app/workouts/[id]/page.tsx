"use client";
import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";
import { useRequireAdmin } from "@/lib/useRequireAdmin";

interface Workout {
  id: string;
  name: string;
  description: string | null;
  is_public: boolean;
  user_id: string | null;
}

interface WorkoutExercise {
  id: string;
  exercise_id: string;
  order: number;
  exercise: { id: string; name: string };
}

interface ExerciseOption {
  id: string;
  name: string;
}

export default function EditWorkoutPage() {
  const { loading } = useRequireAdmin();
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const id = params?.id;
  const [workout, setWorkout] = useState<Workout | null>(null);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [isPublic, setIsPublic] = useState(false);
  const [workoutExercises, setWorkoutExercises] = useState<WorkoutExercise[]>([]);
  const [exOptions, setExOptions] = useState<ExerciseOption[]>([]);
  const [selectedExId, setSelectedExId] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [addingExercise, setAddingExercise] = useState(false);

  useEffect(() => {
    async function fetchWorkout() {
      if (!id) return;
      const { data, error } = await supabase
        .from<Workout>("workouts")
        .select("id, name, description, is_public, user_id")
        .eq("id", id)
        .single();
      if (!error && data) {
        setWorkout(data);
        setName(data.name);
        setDescription(data.description ?? "");
        setIsPublic(data.is_public);
      }
    }
    fetchWorkout();
  }, [id]);

  useEffect(() => {
    async function fetchWorkoutExercises() {
      if (!id) return;
      const { data, error } = await supabase
        .from<WorkoutExercise>("workout_exercises")
        .select(
          "id, exercise_id, order, exercise:exercises(id, name)"
        )
        .eq("workout_id", id)
        .order("order", { ascending: true });
      if (!error && data) {
        setWorkoutExercises(data);
      }
    }
    fetchWorkoutExercises();
  }, [id]);

  const fetchExerciseOptions = async () => {
    const { data, error } = await supabase
      .from<ExerciseOption>("exercises")
      .select("id, name")
      .order("name");
    if (!error && data) {
      setExOptions(data);
    }
  };

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workout) return;
    setSubmitting(true);
    setError(null);
    const { error: updateError } = await supabase
      .from("workouts")
      .update({
        name,
        description,
        is_public: isPublic,
      })
      .eq("id", workout.id);
    if (updateError) {
      setError(updateError.message);
    } else {
      router.push("/workouts");
    }
    setSubmitting(false);
  };

  const handleDelete = async () => {
    if (!workout) return;
    if (!confirm("Are you sure you want to delete this workout?")) return;
    setDeleting(true);
    const { error: deleteError } = await supabase
      .from("workouts")
      .delete()
      .eq("id", workout.id);
    if (deleteError) {
      setError(deleteError.message);
    } else {
      router.push("/workouts");
    }
    setDeleting(false);
  };

  const handleRemoveExercise = async (workoutExerciseId: string) => {
    const { error } = await supabase
      .from("workout_exercises")
      .delete()
      .eq("id", workoutExerciseId);
    if (!error) {
      setWorkoutExercises((prev) => prev.filter((we) => we.id !== workoutExerciseId));
    }
  };

  const handleAddExercise = async () => {
    if (!selectedExId || !workout) return;
    // Determine next order
    const maxOrder = workoutExercises.reduce((max, we) => Math.max(max, we.order), 0);
    const nextOrder = maxOrder + 1;
    const { error, data } = await supabase
      .from("workout_exercises")
      .insert([
        {
          workout_id: workout.id,
          exercise_id: selectedExId,
          order: nextOrder,
        },
      ])
      .select(
        "id, exercise_id, order, exercise:exercises(id, name)"
      )
      .single();
    if (!error && data) {
      setWorkoutExercises((prev) => [...prev, data]);
      setSelectedExId("");
      setAddingExercise(false);
    }
  };

  if (loading || !workout) return <p>Loading...</p>;

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Edit Workout</h1>
      <form onSubmit={handleUpdate} className="space-y-4 max-w-lg">
        <div>
          <label className="block text-sm font-medium">Name</label>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            required
          />
        </div>
        <div>
          <label className="block text-sm font-medium">Description</label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            rows={4}
          />
        </div>
        <div className="flex items-center gap-2">
          <input
            id="isPublic"
            type="checkbox"
            checked={isPublic}
            onChange={(e) => setIsPublic(e.target.checked)}
            className="h-4 w-4 text-blue-600 border-gray-300 rounded"
          />
          <label htmlFor="isPublic" className="text-sm font-medium">Public</label>
        </div>
        {error && <p className="text-sm text-red-600">{error}</p>}
        <div className="flex gap-2">
          <button
            type="submit"
            className="py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
            disabled={submitting}
          >
            {submitting ? "Saving..." : "Save"}
          </button>
          <button
            type="button"
            onClick={() => router.back()}
            className="py-2 px-4 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleDelete}
            className="ml-auto py-2 px-4 bg-red-600 text-white rounded-md hover:bg-red-700 disabled:opacity-50"
            disabled={deleting}
          >
            {deleting ? "Deleting..." : "Delete"}
          </button>
        </div>
      </form>
      <div className="max-w-lg">
        <h2 className="text-xl font-semibold mt-8 mb-2">Exercises</h2>
        {workoutExercises.length === 0 && <p className="text-sm text-gray-500">No exercises in this workout.</p>}
        <ul className="divide-y divide-gray-200">
          {workoutExercises.map((we) => (
            <li key={we.id} className="flex items-center justify-between py-2">
              <span>
                {we.order}. {we.exercise.name}
              </span>
              <button
                onClick={() => handleRemoveExercise(we.id)}
                className="text-red-600 hover:text-red-800 text-sm"
              >
                Remove
              </button>
            </li>
          ))}
        </ul>
        {addingExercise ? (
          <div className="mt-4 space-y-2">
            <div className="flex items-center gap-2">
              <select
                value={selectedExId}
                onChange={(e) => setSelectedExId(e.target.value)}
                className="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              >
                <option value="">Select exercise</option>
                {exOptions.map((opt) => (
                  <option key={opt.id} value={opt.id}>{opt.name}</option>
                ))}
              </select>
              <button
                onClick={handleAddExercise}
                className="py-2 px-4 bg-green-600 text-white rounded-md hover:bg-green-700"
                disabled={!selectedExId}
              >
                Add
              </button>
              <button
                onClick={() => setAddingExercise(false)}
                className="py-2 px-4 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300"
              >
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <button
            onClick={() => {
              setAddingExercise(true);
              if (exOptions.length === 0) {
                fetchExerciseOptions();
              }
            }}
            className="mt-4 py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700"
          >
            Add Exercise
          </button>
        )}
      </div>
    </div>
  );
}