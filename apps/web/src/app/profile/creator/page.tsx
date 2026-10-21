"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import {
  DollarSign,
  BarChart3,
  Radio,
  Archive,
  ChevronRight,
} from "lucide-react";
import { useAuthStore } from "@/lib/stores";
import { creatorToolsEnabled, setCreatorMode } from "@/lib/creator-mode";

const tools = [
  {
    href: "/profile/creator/earnings",
    title: "Earnings & Withdrawals",
    subtitle: "Balance, payouts, history",
    icon: DollarSign,
  },
  {
    href: "/profile/creator/analytics",
    title: "Performance Analytics",
    subtitle: "Views, engagement, revenue",
    icon: BarChart3,
  },
  {
    href: "/profile/creator/plan",
    title: "Private Livestream",
    subtitle: "Per-minute pricing, talk-back",
    icon: Radio,
  },
  {
    href: "/profile/creator/clips",
    title: "Clip Archive",
    subtitle: "Archived collectibles",
    icon: Archive,
  },
];

export default function CreatorHubPage() {
  const router = useRouter();
  const user = useAuthStore((s) => s.user);
  const [enabled, setEnabled] = useState(() => creatorToolsEnabled(user));

  if (!enabled) {
    return (
      <AuthGuard>
        <PageHeader title="Creator tools" backHref="/profile/me" />
        <div className="mx-auto max-w-md px-4 py-16 text-center">
          <p className="font-display text-lg font-bold text-white">Turn on Creator mode</p>
          <p className="mt-2 text-sm text-zinc-400">
            Enable Creator mode to access creator tools and mint collectible clips.
          </p>
          <button
            type="button"
            onClick={() => {
              setCreatorMode(true);
              setEnabled(true);
            }}
            className="mt-6 rounded-full brand-gradient px-5 py-2.5 text-xs font-bold text-white shadow-md shadow-brand-purple/20"
          >
            Enable Creator mode
          </button>
          <button
            type="button"
            onClick={() => router.push("/profile/settings/preferences")}
            className="mt-3 block w-full text-xs font-semibold text-zinc-400 hover:text-white"
          >
            Open General settings
          </button>
        </div>
      </AuthGuard>
    );
  }
  return (
    <AuthGuard>
      <PageHeader title="Creator tools" backHref="/profile/me" />

      <div className="mx-auto max-w-md px-4 py-6 pb-24 space-y-3">
        <div className="space-y-2.5">
          {tools.map((item) => {
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                className="group flex items-center justify-between rounded-3xl border border-white/10 bg-[#141420]/80 p-4 backdrop-blur-xl transition hover:border-brand-purple/40 hover:bg-[#181828]"
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
      </div>
    </AuthGuard>
  );
}
