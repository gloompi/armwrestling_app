"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "./supabaseClient";

/**
 * Ensures that the current user is authenticated and has the admin role.
 * Redirects to the login page if not authenticated or not an admin.
 * Returns loading state.
 */
export function useRequireAdmin() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    async function check() {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      const user = session?.user;
      if (!user) {
        router.replace("/login");
        return;
      }
      // fetch profile to check role and ban status
      const { data: profile, error } = await supabase
        .from("profiles")
        .select("role, is_banned")
        .eq("id", user.id)
        .single();
      if (error || !profile) {
        // if profile doesn't exist or error, deny access
        router.replace("/login");
        return;
      }
      if (profile.is_banned || profile.role !== "admin") {
        router.replace("/login");
        return;
      }
      if (mounted) setLoading(false);
    }
    check();
    return () => {
      mounted = false;
    };
  }, [router]);
  return { loading };
}