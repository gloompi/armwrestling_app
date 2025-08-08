"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useRequireAdmin } from "@/lib/useRequireAdmin";

interface Exercise {
  id: string;
  name: string;
  description: string | null;
  preview_url: string | null;
  recommended_sets: number | null;
  recommended_reps: number | null;
}

export default function ExercisesPage() {
  const { loading } = useRequireAdmin();
  const [exercises, setExercises] = useState<Exercise[]>([]);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  useEffect(() => {
    async function fetchExercises() {
      const { data, error } = await supabase
        .from("exercises")
        .select("id, name, description, preview_url, recommended_sets, recommended_reps")
        .order("name", { ascending: true });
      if (!error && data) {
        setExercises(data);
      }
    }
    fetchExercises();
  }, []);

  const deleteExercise = async (id: string) => {
    if (!confirm("Are you sure you want to delete this exercise?")) return;
    setDeletingId(id);
    const { error } = await supabase
      .from("exercises")
      .delete()
      .eq("id", id);
    if (!error) {
      setExercises((prev) => prev.filter((ex) => ex.id !== id));
    }
    setDeletingId(null);
  };

  if (loading) return <p>Loading...</p>;

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">Exercises</h1>
        <Link
          href="/exercises/new"
          className="py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700"
        >
          Add Exercise
        </Link>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Name
              </th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Sets
              </th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Reps
              </th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Preview
              </th>
              <th className="px-3 py-2"></th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {exercises.map((ex) => (
              <tr key={ex.id}>
                <td className="px-3 py-2 whitespace-nowrap font-medium text-gray-900">
                  {ex.name}
                </td>
                <td className="px-3 py-2 whitespace-nowrap">
                  {ex.recommended_sets ?? "-"}
                </td>
                <td className="px-3 py-2 whitespace-nowrap">
                  {ex.recommended_reps ?? "-"}
                </td>
                <td className="px-3 py-2 whitespace-nowrap">
                  {ex.preview_url ? (
                    <a
                      href={ex.preview_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-blue-600 hover:underline"
                    >
                      View
                    </a>
                  ) : (
                    "-"
                  )}
                </td>
                <td className="px-3 py-2 whitespace-nowrap text-right text-sm font-medium space-x-2">
                  <Link
                    href={`/exercises/${ex.id}`}
                    className="text-blue-600 hover:text-blue-800"
                  >
                    Edit
                  </Link>
                  <button
                    onClick={() => deleteExercise(ex.id)}
                    className="text-red-600 hover:text-red-800"
                    disabled={deletingId === ex.id}
                  >
                    {deletingId === ex.id ? "Deleting..." : "Delete"}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}