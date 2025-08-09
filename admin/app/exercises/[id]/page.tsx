"use client";
import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";
import { uploadFile } from "@/lib/storage";
import { useRequireAdmin } from "@/lib/useRequireAdmin";

interface Exercise {
  id: string;
  name: string;
  description: string | null;
  preview_url: string | null;
  recommended_sets: number | null;
  recommended_reps: number | null;
  recommended_rest_seconds: number | null;
}

export default function EditExercisePage() {
  const { loading } = useRequireAdmin();
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const id = params?.id;
  const [exercise, setExercise] = useState<Exercise | null>(null);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [previewUrl, setPreviewUrl] = useState("");
  const [previewFile, setPreviewFile] = useState<File | null>(null);
  const [sets, setSets] = useState("");
  const [reps, setReps] = useState("");
  const [rest, setRest] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    async function fetchExercise() {
      if (!id) return;
      const { data, error } = await supabase
        .from("exercises")
        .select(
          "id, name, description, preview_url, recommended_sets, recommended_reps, recommended_rest_seconds",
        )
        .eq("id", id)
        .single();
      if (!error && data) {
        setExercise(data);
        setName(data.name);
        setDescription(data.description ?? "");
        setPreviewUrl(data.preview_url ?? "");
        setSets(data.recommended_sets?.toString() ?? "");
        setReps(data.recommended_reps?.toString() ?? "");
        setRest(data.recommended_rest_seconds?.toString() ?? "");
      }
    }
    fetchExercise();
  }, [id]);

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!exercise) return;
    setSubmitting(true);
    setError(null);
    try {
      // If a new file is selected, upload it and use its public URL. Otherwise use the text field.
      let finalPreviewUrl: string | null = null;
      if (previewFile) {
        finalPreviewUrl = await uploadFile(previewFile);
      } else if (previewUrl.trim() !== "") {
        finalPreviewUrl = previewUrl.trim();
      }
      const { error: updateError } = await supabase
        .from("exercises")
        .update({
          name,
          description,
          preview_url: finalPreviewUrl,
          recommended_sets: sets ? parseInt(sets, 10) : null,
          recommended_reps: reps ? parseInt(reps, 10) : null,
          recommended_rest_seconds: rest ? parseInt(rest, 10) : null,
        })
        .eq("id", exercise.id);
      if (updateError) {
        throw updateError;
      }
      router.push("/exercises");
    } catch (err: any) {
      setError(err.message ?? String(err));
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async () => {
    if (!exercise) return;
    if (!confirm("Are you sure you want to delete this exercise?")) return;
    setDeleting(true);
    const { error: deleteError } = await supabase
      .from("exercises")
      .delete()
      .eq("id", exercise.id);
    if (deleteError) {
      setError(deleteError.message);
    } else {
      router.push("/exercises");
    }
    setDeleting(false);
  };

  if (loading || !exercise) return <p>Loading...</p>;

  return (
    <div className="max-w-lg mx-auto">
      <h1 className="text-2xl font-bold mb-4">Edit Exercise</h1>
      <form onSubmit={handleUpdate} className="space-y-4">
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
        <div>
          <label className="block text-sm font-medium">Preview URL</label>
          <input
            type="url"
            value={previewUrl}
            onChange={(e) => setPreviewUrl(e.target.value)}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            placeholder="Enter external URL (optional if uploading file)"
          />
          <div className="mt-2">
            <label className="block text-sm font-medium">Or upload new file</label>
            <input
              type="file"
              accept="image/*"
              onChange={(e) => setPreviewFile(e.target.files?.[0] ?? null)}
              className="mt-1 block w-full text-sm"
            />
          </div>
        </div>
        <div className="grid grid-cols-3 gap-4">
          <div>
            <label className="block text-sm font-medium">Recommended Sets</label>
            <input
              type="number"
              value={sets}
              onChange={(e) => setSets(e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              min="0"
            />
          </div>
          <div>
            <label className="block text-sm font-medium">Recommended Reps</label>
            <input
              type="number"
              value={reps}
              onChange={(e) => setReps(e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              min="0"
            />
          </div>
          <div>
            <label className="block text-sm font-medium">Recommended Rest (seconds)</label>
            <input
              type="number"
              value={rest}
              onChange={(e) => setRest(e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              min="0"
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