"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { signOut } from "@/lib/api/auth";
import { disconnectSocket } from "@/lib/socket";
import { useAuthStore } from "@/lib/stores";
import { creatorToolsEnabled } from "@/lib/creator-mode";
import {
  User,
  Bell,
  Sliders,
  Shield,
  UserX,
  Sparkles,
  ChevronRight,
  LogOut,
  Bookmark,
} from "lucide-react";

const settingsGroups = [
  {
    href: "/profile/me/edit",
    title: "Personal info",
    subtitle: "Profile, avatar, bio",
    icon: User,
  },
  {
    href: "/profile/saved",
    title: "Saved",
    subtitle: "Media you saved",
    icon: Bookmark,
  },
  {
    href: "/profile/settings/notifications",
    title: "Notifications",
    subtitle: "Sounds, live alerts, calls",
    icon: Bell,
  },
  {
    href: "/profile/settings/preferences",
    title: "General",
    subtitle: "Discoverability, theme, filters",
    icon: Sliders,
  },
  {
    href: "/profile/settings/security",
    title: "Security",
    subtitle: "Password and app passcode",
    icon: Shield,
  },
  {
    href: "/profile/settings/blocked",
    title: "Blocked accounts",
    subtitle: "Manage blocked users",
    icon: UserX,
  },
  {
    href: "/profile/creator",
    title: "Creator tools",
    subtitle: "Earnings, analytics, live, archive",
    icon: Sparkles,
  },
];

export default function SettingsPage() {
  const router = useRouter();
  const user = useAuthStore((s) => s.user);
  const { setUser, setAuthenticated } = useAuthStore();
  const showCreatorTools = creatorToolsEnabled(user);

  async function handleSignOut() {
    await signOut();
    disconnectSocket();
    setUser(null);
    setAuthenticated(false);
    router.push("/auth/sign-in");
  }

  const visibleGroups = settingsGroups.filter((item) => item.href !== "/profile/creator" || showCreatorTools);

  return (
    <AuthGuard>
      <PageHeader title="Settings" backHref="/profile/me" />

      <div className="mx-auto max-w-md px-4 py-6 pb-24 space-y-3">
        <div className="space-y-2.5">
          {visibleGroups.map((item) => {
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                className="group flex items-center justify-between rounded-3xl border border-white/10 bg-[#141420]/75 p-4 backdrop-blur-xl transition hover:border-brand-purple/40 hover:bg-[#181828]"
              >
                <div className="flex items-center gap-3.5">
                  <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-white/5 text-zinc-300 transition group-hover:bg-brand-purple/20 group-hover:text-brand-purple">
                    <Icon className="h-5 w-5" />
                  </div>
                  <div>
                    <p className="font-display text-sm font-bold text-white group-hover:text-brand-purple transition-colors">
                      {item.title}
                    </p>
                    <p className="text-xs text-zinc-400">{item.subtitle}</p>
                  </div>
                </div>
                <ChevronRight className="h-4 w-4 text-zinc-500 transition-transform group-hover:translate-x-0.5 group-hover:text-white" />
              </Link>
            );
          })}
        </div>

        <div className="pt-3">
          <button
            type="button"
            onClick={handleSignOut}
            className="group flex w-full items-center justify-between rounded-3xl border border-red-500/20 bg-red-500/5 p-4 transition hover:bg-red-500/10"
          >
            <div className="flex items-center gap-3.5">
              <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-red-500/10 text-red-400">
                <LogOut className="h-5 w-5" />
              </div>
              <div className="text-left">
                <p className="font-display text-sm font-bold text-red-400">Log out</p>
                <p className="text-xs text-red-400/70">Sign out of your XLive account</p>
              </div>
            </div>
            <ChevronRight className="h-4 w-4 text-red-400/50" />
          </button>
        </div>
      </div>
    </AuthGuard>
  );
}
