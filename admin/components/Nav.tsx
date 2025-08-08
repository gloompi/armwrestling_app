"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import clsx from "clsx";

const navItems = [
  { href: "/", label: "Dashboard" },
  { href: "/exercises", label: "Exercises" },
  { href: "/workouts", label: "Workouts" },
  { href: "/videos", label: "Videos" },
  { href: "/categories", label: "Categories" },
  { href: "/users", label: "Users" },
];

export default function Nav() {
  const pathname = usePathname();
  return (
    <nav className="flex gap-4 whitespace-nowrap overflow-x-auto py-4 px-2 text-sm border-b border-gray-200 bg-white">
      {navItems.map((item) => {
        const active = pathname === item.href || pathname.startsWith(item.href + "/");
        return (
          <Link
            key={item.href}
            href={item.href}
            className={clsx(
              "px-3 py-2 rounded-md font-medium transition-colors",
              active
                ? "bg-blue-600 text-white"
                : "text-gray-700 hover:bg-gray-100"
            )}
          >
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}