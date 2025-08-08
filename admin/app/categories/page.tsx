"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useRequireAdmin } from "@/lib/useRequireAdmin";

interface Category {
  id: string;
  name: string;
  description: string | null;
}

// This page lists all categories and allows admins to create, edit or delete them.
// Only admins can access this page via the useRequireAdmin hook.
export default function CategoriesPage() {
  const { loading } = useRequireAdmin();
  const [categories, setCategories] = useState<Category[]>([]);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  useEffect(() => {
    async function fetchCategories() {
      const { data, error } = await supabase
        .from("categories")
        .select("id, name, description")
        .order("name", { ascending: true });
      if (!error && data) {
        setCategories(data);
      }
    }
    fetchCategories();
  }, []);

  const deleteCategory = async (id: string) => {
    if (!confirm("Are you sure you want to delete this category?")) return;
    setDeletingId(id);
    const { error } = await supabase
      .from("categories")
      .delete()
      .eq("id", id);
    if (!error) {
      setCategories((prev) => prev.filter((c) => c.id !== id));
    }
    setDeletingId(null);
  };

  if (loading) return <p>Loading...</p>;

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">Categories</h1>
        <Link
          href="/categories/new"
          className="py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700"
        >
          Add Category
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
                Description
              </th>
              <th className="px-3 py-2"></th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {categories.map((c) => (
              <tr key={c.id}>
                <td className="px-3 py-2 whitespace-nowrap font-medium text-gray-900">
                  {c.name}
                </td>
                <td className="px-3 py-2 whitespace-nowrap max-w-md truncate">
                  {c.description ?? "-"}
                </td>
                <td className="px-3 py-2 whitespace-nowrap text-right text-sm font-medium space-x-2">
                  <Link
                    href={`/categories/${c.id}`}
                    className="text-blue-600 hover:text-blue-800"
                  >
                    Edit
                  </Link>
                  <button
                    onClick={() => deleteCategory(c.id)}
                    className="text-red-600 hover:text-red-800"
                    disabled={deletingId === c.id}
                  >
                    {deletingId === c.id ? "Deleting..." : "Delete"}
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