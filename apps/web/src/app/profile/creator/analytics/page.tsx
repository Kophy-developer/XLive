"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { getCreatorAnalytics, CreatorAnalyticsData } from "@/lib/api/creator";

export default function CreatorAnalyticsPage() {
  const [range, setRange] = useState<"today" | "week" | "month">("today");

  const { data } = useQuery<CreatorAnalyticsData>({
    queryKey: ["creator-analytics", range],
    queryFn: () => getCreatorAnalytics(range),
  });

  const m = data?.metrics ?? {
    likes: 0,
    comments: 0,
    shares: 0,
    profileViews: 0,
    postViews: 0,
    clipViews: 0,
    liveStreams: 0,
    streamJoins: 0,
    watchTimeSeconds: 0,
    giftRevenue: 0,
  };

  const watchTimeMinutes = Math.round((m.watchTimeSeconds ?? 0) / 60);

  const stats = [
    { label: "Likes", value: m.likes ?? 0 },
    { label: "Comments", value: m.comments ?? 0 },
    { label: "Shares", value: m.shares ?? 0 },
    { label: "Profile views", value: m.profileViews ?? 0 },
    { label: "Post views", value: m.postViews ?? 0 },
    { label: "Clip views", value: m.clipViews ?? 0 },
    { label: "Live streams", value: m.liveStreams ?? 0 },
    { label: "Stream joins", value: m.streamJoins ?? 0 },
    { label: "Watch time (min)", value: watchTimeMinutes },
    { label: "Gift revenue", value: `USD ${(m.giftRevenue ?? 0).toFixed(2)}` },
  ];

  return (
    <AuthGuard>
      <PageHeader title="Performance Analytics" backHref="/profile/creator" />

      <div className="mx-auto max-w-md px-4 py-6 pb-24 space-y-5">
        <div className="flex items-center gap-2">
          {(["today", "week", "month"] as const).map((r) => (
            <button
              key={r}
              type="button"
              onClick={() => setRange(r)}
              className={`rounded-full px-4 py-1.5 text-xs font-bold capitalize transition ${
                range === r
                  ? "brand-gradient text-white shadow-md shadow-brand-purple/20"
                  : "border border-white/10 bg-white/5 text-zinc-400 hover:text-white"
              }`}
            >
              {r}
            </button>
          ))}
        </div>

        <div className="grid grid-cols-4 gap-2.5">
          {stats.slice(0, 4).map((s) => (
            <div
              key={s.label}
              className="flex flex-col items-center justify-center rounded-2xl border border-white/10 bg-[#141420]/80 p-3.5 text-center backdrop-blur-xl"
            >
              <p className="font-sans text-base font-bold text-white tracking-tight tabular-nums">{s.value}</p>
              <p className="mt-1 text-[10px] font-medium text-zinc-400">{s.label}</p>
            </div>
          ))}
        </div>

        <div className="grid grid-cols-4 gap-2.5">
          {stats.slice(4, 8).map((s) => (
            <div
              key={s.label}
              className="flex flex-col items-center justify-center rounded-2xl border border-white/10 bg-[#141420]/80 p-3.5 text-center backdrop-blur-xl"
            >
              <p className="font-sans text-base font-bold text-white tracking-tight tabular-nums">{s.value}</p>
              <p className="mt-1 text-[10px] font-medium text-zinc-400">{s.label}</p>
            </div>
          ))}
        </div>

        <div className="grid grid-cols-2 gap-2.5">
          {stats.slice(8).map((s) => (
            <div
              key={s.label}
              className="flex flex-col items-center justify-center rounded-2xl border border-white/10 bg-[#141420]/80 p-4 text-center backdrop-blur-xl"
            >
              <p className="font-sans text-lg font-bold text-white tracking-tight tabular-nums">{s.value}</p>
              <p className="mt-1 text-[10px] font-medium text-zinc-400">{s.label}</p>
            </div>
          ))}
        </div>
      </div>
    </AuthGuard>
  );
}
