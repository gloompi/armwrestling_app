"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useRequireAdmin } from "@/lib/useRequireAdmin";

interface Workout {
  id: string;
  name: string;
  description: string | null;
  is_public: boolean;
  user_id: string | null;
}

export default function WorkoutsPage() {
  const { loading } = useRequireAdmin();
  const [workouts, setWorkouts] = useState<Workout[]>([]);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  useEffect(() => {
    async function fetchWorkouts() {
      const { data, error } = await supabase
        .from("workouts")
        .select("id, name, description, is_public, user_id")
        .order("created_at", { ascending: false });
      if (!error && data) {
        setWorkouts(data);
      }
    }
    fetchWorkouts();
  }, []);

  const deleteWorkout = async (id: string) => {
    if (!confirm("Are you sure you want to delete this workout?")) return;
    setDeletingId(id);
    const { error } = await supabase
      .from("workouts")
      .delete()
      .eq("id", id);
    if (!error) {
      setWorkouts((prev) => prev.filter((w) => w.id !== id));
    }
    setDeletingId(null);
  };

  if (loading) return <p>Loading...</p>;

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">Workouts</h1>
        <Link
          href="/workouts/new"
          className="py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700"
        >
          Add Workout
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
                Public
              </th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Owner
              </th>
              <th className="px-3 py-2"></th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {workouts.map((w) => (
              <tr key={w.id}>
                <td className="px-3 py-2 whitespace-nowrap font-medium text-gray-900">
                  {w.name}
                </td>
                <td className="px-3 py-2 whitespace-nowrap">
                  {w.is_public ? "Yes" : "No"}
                </td>
                <td className="px-3 py-2 whitespace-nowrap">
                  {w.user_id ?? "-"}
                </td>
                <td className="px-3 py-2 whitespace-nowrap text-right text-sm font-medium space-x-2">
                  <Link
                    href={`/workouts/${w.id}`}
                    className="text-blue-600 hover:text-blue-800"
                  >
                    Edit
                  </Link>
                  <button
                    onClick={() => deleteWorkout(w.id)}
                    className="text-red-600 hover:text-red-800"
                    disabled={deletingId === w.id}
                  >
                    {deletingId === w.id ? "Deleting..." : "Delete"}
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