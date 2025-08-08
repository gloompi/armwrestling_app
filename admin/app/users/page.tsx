"use client";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import { useRequireAdmin } from "@/lib/useRequireAdmin";

interface Profile {
  id: string;
  role: string;
  is_banned: boolean;
}

// Page to manage user roles and banned status. Admins can promote/demote or ban/unban users.
export default function UsersPage() {
  const { loading } = useRequireAdmin();
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [updatingId, setUpdatingId] = useState<string | null>(null);

  useEffect(() => {
    async function fetchProfiles() {
      const { data, error } = await supabase
        .from("profiles")
        .select("id, role, is_banned")
        .order("id");
      if (!error && data) {
        setProfiles(data);
      }
    }
    fetchProfiles();
  }, []);

  const toggleBan = async (profile: Profile) => {
    setUpdatingId(profile.id);
    const { error } = await supabase
      .from("profiles")
      .update({ is_banned: !profile.is_banned })
      .eq("id", profile.id);
    if (!error) {
      setProfiles((prev) =>
        prev.map((p) => (p.id === profile.id ? { ...p, is_banned: !profile.is_banned } : p))
      );
    }
    setUpdatingId(null);
  };

  const toggleRole = async (profile: Profile) => {
    setUpdatingId(profile.id);
    const newRole = profile.role === "admin" ? "user" : "admin";
    const { error } = await supabase
      .from("profiles")
      .update({ role: newRole })
      .eq("id", profile.id);
    if (!error) {
      setProfiles((prev) =>
        prev.map((p) => (p.id === profile.id ? { ...p, role: newRole } : p))
      );
    }
    setUpdatingId(null);
  };

  if (loading) return <p>Loading...</p>;

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Users</h1>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                User ID
              </th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Role
              </th>
              <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Banned
              </th>
              <th className="px-3 py-2"></th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {profiles.map((profile) => (
              <tr key={profile.id}>
                <td className="px-3 py-2 whitespace-nowrap text-gray-900 text-sm">
                  {profile.id}
                </td>
                <td className="px-3 py-2 whitespace-nowrap text-sm">
                  {profile.role}
                </td>
                <td className="px-3 py-2 whitespace-nowrap text-sm">
                  {profile.is_banned ? "Yes" : "No"}
                </td>
                <td className="px-3 py-2 whitespace-nowrap text-right text-sm font-medium space-x-2">
                  <button
                    onClick={() => toggleRole(profile)}
                    className="text-blue-600 hover:text-blue-800"
                    disabled={updatingId === profile.id}
                  >
                    {profile.role === "admin" ? "Demote" : "Promote"}
                  </button>
                  <button
                    onClick={() => toggleBan(profile)}
                    className="text-red-600 hover:text-red-800"
                    disabled={updatingId === profile.id}
                  >
                    {profile.is_banned ? "Unban" : "Ban"}
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