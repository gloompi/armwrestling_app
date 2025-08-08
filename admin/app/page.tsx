"use client";
import { supabase } from "@/lib/supabaseClient";
import { useRequireAdmin } from "@/lib/useRequireAdmin";
import { useEffect, useState } from "react";

export default function DashboardPage() {
  const { loading } = useRequireAdmin();
  const [stats, setStats] = useState<{ exercises: number; workouts: number; videos: number; users: number }>({ exercises: 0, workouts: 0, videos: 0, users: 0 });

  useEffect(() => {
    async function fetchStats() {
      const [exercises, workouts, videos, users] = await Promise.all([
        supabase.from("exercises").select("id", { count: "exact", head: true }),
        supabase.from("workouts").select("id", { count: "exact", head: true }),
        supabase.from("videos").select("id", { count: "exact", head: true }),
        supabase.from("profiles").select("id", { count: "exact", head: true }),
      ]);
      setStats({
        exercises: exercises.count || 0,
        workouts: workouts.count || 0,
        videos: videos.count || 0,
        users: users.count || 0,
      });
    }
    fetchStats();
  }, []);

  if (loading) return <p>Loading...</p>;

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Admin Dashboard</h1>
      <p className="text-gray-600">Quick overview of your app's data.</p>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="p-4 bg-white rounded shadow">
          <p className="text-sm text-gray-500">Exercises</p>
          <p className="text-2xl font-semibold">{stats.exercises}</p>
        </div>
        <div className="p-4 bg-white rounded shadow">
          <p className="text-sm text-gray-500">Workouts</p>
          <p className="text-2xl font-semibold">{stats.workouts}</p>
        </div>
        <div className="p-4 bg-white rounded shadow">
          <p className="text-sm text-gray-500">Videos</p>
          <p className="text-2xl font-semibold">{stats.videos}</p>
        </div>
        <div className="p-4 bg-white rounded shadow">
          <p className="text-sm text-gray-500">Users</p>
          <p className="text-2xl font-semibold">{stats.users}</p>
        </div>
      </div>
    </div>
  );
}