"use client";
import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";
import { uploadFile } from "@/lib/storage";
import { useRequireAdmin } from "@/lib/useRequireAdmin";

interface Video {
  id: string;
  title: string;
  description: string | null;
  url: string;
}

// Page to edit or delete an existing video. Only accessible to admins.
export default function EditVideoPage() {
  const { loading } = useRequireAdmin();
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const id = params?.id;
  const [video, setVideo] = useState<Video | null>(null);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [url, setUrl] = useState("");
  const [videoFile, setVideoFile] = useState<File | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    async function fetchVideo() {
      if (!id) return;
      const { data, error } = await supabase
        .from("videos")
        .select("id, title, description, url")
        .eq("id", id)
        .single();
      if (!error && data) {
        setVideo(data);
        setTitle(data.title);
        setDescription(data.description ?? "");
        setUrl(data.url);
      }
    }
    fetchVideo();
  }, [id]);

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!video) return;
    setSubmitting(true);
    setError(null);
    try {
      let finalUrl: string | null = null;
      if (videoFile) {
        finalUrl = await uploadFile(videoFile);
      } else if (url.trim() !== "") {
        finalUrl = url.trim();
      }
      const { error: updateError } = await supabase
        .from("videos")
        .update({ title, description, url: finalUrl })
        .eq("id", video.id);
      if (updateError) {
        throw updateError;
      }
      router.push("/videos");
    } catch (err: any) {
      setError(err.message ?? String(err));
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async () => {
    if (!video) return;
    if (!confirm("Are you sure you want to delete this video?")) return;
    setDeleting(true);
    const { error: deleteError } = await supabase
      .from("videos")
      .delete()
      .eq("id", video.id);
    if (deleteError) {
      setError(deleteError.message);
    } else {
      router.push("/videos");
    }
    setDeleting(false);
  };

  if (loading || !video) return <p>Loading...</p>;

  return (
    <div className="max-w-lg mx-auto">
      <h1 className="text-2xl font-bold mb-4">Edit Video</h1>
      <form onSubmit={handleUpdate} className="space-y-4">
        <div>
          <label className="block text-sm font-medium">Title</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
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
        <div>
          <label className="block text-sm font-medium">Video URL</label>
          <input
            type="url"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            placeholder="Enter external URL (optional if uploading file)"
          />
          <div className="mt-2">
            <label className="block text-sm font-medium">Or upload new file</label>
            <input
              type="file"
              accept="video/*"
              onChange={(e) => setVideoFile(e.target.files?.[0] ?? null)}
              className="mt-1 block w-full text-sm"
            />
          </div>
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
    </div>
  );
}