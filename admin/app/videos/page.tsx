"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useRequireAdmin } from "@/lib/useRequireAdmin";

interface Video {
  id: string;
  title: string;
  description: string | null;
  url: string;
}

export default function VideosPage() {
  const { loading } = useRequireAdmin();
  const [videos, setVideos] = useState<Video[]>([]);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  useEffect(() => {
    async function fetchVideos() {
      const { data, error } = await supabase
        .from<Video>("videos")
        .select("id, title, description, url")
        .order("created_at", { ascending: false });
      if (!error && data) {
        setVideos(data);
      }
    }
    fetchVideos();
  }, []);

  const deleteVideo = async (id: string) => {
    if (!confirm("Are you sure you want to delete this video?")) return;
    setDeletingId(id);
    const { error } = await supabase
      .from("videos")
      .delete()
      .eq("id", id);
    if (!error) {
      setVideos((prev) => prev.filter((v) => v.id !== id));
    }
    setDeletingId(null);
  };

  if (loading) return <p>Loading...</p>;

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">Videos</h1>
        <Link
          href="/videos/new"
          className="py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700"
        >
          Add Video
        </Link>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Title
              </th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                URL
              </th>
              <th className="px-3 py-2"></th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {videos.map((v) => (
              <tr key={v.id}>
                <td className="px-3 py-2 whitespace-nowrap font-medium text-gray-900">
                  {v.title}
                </td>
                <td className="px-3 py-2 whitespace-nowrap max-w-xs truncate">
                  <a
                    href={v.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-600 hover:underline"
                  >
                    {v.url}
                  </a>
                </td>
                <td className="px-3 py-2 whitespace-nowrap text-right text-sm font-medium space-x-2">
                  <Link
                    href={`/videos/${v.id}`}
                    className="text-blue-600 hover:text-blue-800"
                  >
                    Edit
                  </Link>
                  <button
                    onClick={() => deleteVideo(v.id)}
                    className="text-red-600 hover:text-red-800"
                    disabled={deletingId === v.id}
                  >
                    {deletingId === v.id ? "Deleting..." : "Delete"}
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