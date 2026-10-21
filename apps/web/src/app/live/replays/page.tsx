"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { getReplays } from "@/lib/api/streams";
import { cloudinaryUrl } from "@/lib/utils";
import { Play, Video } from "lucide-react";

function formatReplayDate(dateStr?: string) {
  if (!dateStr) return "";
  try {
    const d = new Date(dateStr);
    return d.toLocaleString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    });
  } catch {
    return dateStr;
  }
}

export default function ReplaysPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["replays"],
    queryFn: () => getReplays(1, 50),
  });

  const replays = data?.replays ?? [];

  return (
    <AuthGuard>
      <div className="mx-auto max-w-5xl px-4 py-6 md:px-8">
        <PageHeader title="Saved Replays" backHref="/live" />

        {isLoading ? (
          <div className="flex justify-center py-24">
            <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
          </div>
        ) : !replays.length ? (
          <div className="flex flex-col items-center justify-center rounded-3xl border border-white/10 bg-[#141420]/70 py-20 text-center">
            <Video className="h-12 w-12 text-zinc-600 mb-3" />
            <p className="font-sans text-sm font-bold text-white">No replays available yet</p>
            <p className="mt-1 text-xs text-zinc-400">Streams saved as replays will appear here.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3 lg:grid-cols-4">
            {replays.map((r) => (
              <Link
                key={r.id}
                href={`/live/replay/${r.id}`}
                className="group relative flex flex-col overflow-hidden rounded-[24px] border border-white/10 bg-[#161622] shadow-xl transition hover:border-brand-purple/50 active:scale-98"
              >
                <div className="relative aspect-[3/4] w-full bg-[#101018] flex items-center justify-center overflow-hidden">
                  {r.thumbnailUrl ? (
                    <img
                      src={cloudinaryUrl(r.thumbnailUrl, "c_fill,w_400,h_530")}
                      alt=""
                      className="h-full w-full object-cover transition group-hover:scale-105"
                    />
                  ) : (
                    <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-[#181828] to-[#0c0c14]">
                      <Video className="h-10 w-10 text-zinc-600" />
                    </div>
                  )}

                  <div className="absolute inset-0 bg-black/30 transition group-hover:bg-black/10" />

                  <div className="absolute left-3 top-3 rounded-lg border border-brand-purple/40 bg-brand-purple/30 px-2 py-0.5 font-sans text-[10px] font-extrabold uppercase tracking-wide text-brand-purple backdrop-blur-md">
                    REPLAY
                  </div>

                  <div className="absolute flex h-12 w-12 items-center justify-center rounded-full bg-black/60 text-white shadow-xl backdrop-blur-md transition group-hover:scale-110 group-hover:bg-brand-purple">
                    <Play className="h-5 w-5 fill-white stroke-none ml-0.5" />
                  </div>
                </div>

                <div className="p-3">
                  <p className="font-sans text-xs font-bold text-white truncate">{r.title}</p>
                  <p className="mt-1 font-sans text-[11px] font-semibold text-zinc-400 tabular-nums">
                    {formatReplayDate(r.createdAt || r.startedAt)}
                  </p>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </AuthGuard>
  );
}
