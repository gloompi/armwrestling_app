"use client";
import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { supabase } from "@/lib/supabaseClient";
import { useRequireAdmin } from "@/lib/useRequireAdmin";

interface Category {
  id: string;
  name: string;
  description: string | null;
}

// Page to edit an existing category. Also allows deletion.
export default function EditCategoryPage() {
  const { loading } = useRequireAdmin();
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const id = params?.id;
  const [category, setCategory] = useState<Category | null>(null);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    async function fetchCategory() {
      if (!id) return;
      const { data, error } = await supabase
        .from("categories")
        .select("id, name, description")
        .eq("id", id)
        .single();
      if (!error && data) {
        setCategory(data);
        setName(data.name);
        setDescription(data.description ?? "");
      }
    }
    fetchCategory();
  }, [id]);

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!category) return;
    setSubmitting(true);
    setError(null);
    const { error: updateError } = await supabase
      .from("categories")
      .update({ name, description })
      .eq("id", category.id);
    if (updateError) {
      setError(updateError.message);
    } else {
      router.push("/categories");
    }
    setSubmitting(false);
  };

  const handleDelete = async () => {
    if (!category) return;
    if (!confirm("Are you sure you want to delete this category?")) return;
    setDeleting(true);
    const { error: deleteError } = await supabase
      .from("categories")
      .delete()
      .eq("id", category.id);
    if (deleteError) {
      setError(deleteError.message);
    } else {
      router.push("/categories");
    }
    setDeleting(false);
  };

  if (loading || !category) return <p>Loading...</p>;

  return (
    <div className="max-w-lg mx-auto">
      <h1 className="text-2xl font-bold mb-4">Edit Category</h1>
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