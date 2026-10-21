"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { AuthGuard } from "@/components/auth-guard";
import { AccountChip } from "@/components/account-chip";
import { signOut } from "@/lib/api/auth";
import { getLiveStreams, getReplays } from "@/lib/api/streams";
import { cloudinaryUrl, cn } from "@/lib/utils";
import {
  ArrowLeft,
  Play,
  Plus,
  Radio,
  RefreshCw,
  Users,
  Video,
} from "lucide-react";

function formatReplayDate(dateStr?: string) {
  if (!dateStr) return "";
  try {
    const d = new Date(dateStr);
    return d.toLocaleString("en-US", {
      month: "numeric",
      day: "numeric",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit",
      second: "2-digit",
      hour12: true,
    });
  } catch {
    return dateStr;
  }
}

export default function LiveHubPage() {
  const router = useRouter();

  const {
    data: liveData,
    isLoading: loadingLive,
    refetch: refetchLive,
    isRefetching: refetchingLive,
  } = useQuery({
    queryKey: ["live-streams"],
    queryFn: getLiveStreams,
    refetchInterval: 15000,
  });

  const {
    data: replaysData,
    isLoading: loadingReplays,
    refetch: refetchReplays,
    isRefetching: refetchingReplays,
  } = useQuery({
    queryKey: ["replays"],
    queryFn: () => getReplays(1, 40),
  });

  const streams = liveData?.streams ?? [];
  const replays = replaysData?.replays ?? [];

  return (
    <AuthGuard>
      <div className="relative mx-auto max-w-4xl px-4 py-6 pb-28 md:px-8">
        <header className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => router.push("/home")}
              className="flex h-10 w-10 items-center justify-center rounded-2xl border border-white/10 bg-white/5 text-white transition hover:bg-white/10 active:scale-95"
            >
              <ArrowLeft className="h-5 w-5" />
            </button>
            <div className="flex items-center gap-2">
              <img src="/logo.png" alt="XLive" className="h-8 w-auto object-contain" />
            </div>
          </div>

          <div className="flex items-center gap-2.5">
            <AccountChip className="hidden md:flex" />
            <button
              type="button"
              onClick={async () => {
                await signOut();
                router.push("/auth/sign-in");
              }}
              className="rounded-2xl border border-white/10 bg-white/5 px-3 py-1.5 font-sans text-xs font-semibold text-zinc-300 transition hover:bg-white/10 hover:text-white"
            >
              Log out
            </button>
          </div>
        </header>

        <div className="mb-8">
          <h1 className="font-sans text-2xl font-bold tracking-tight text-white md:text-3xl">
            Live Now
          </h1>
          <p className="mt-1 font-sans text-xs text-zinc-400 md:text-sm">
            Watch creators streaming in real time
          </p>
        </div>

        <section className="mb-10">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="font-sans text-xs font-bold uppercase tracking-wider text-zinc-300">
              Broadcasts
            </h2>
            <button
              type="button"
              onClick={() => refetchLive()}
              disabled={refetchingLive}
              className="flex items-center gap-1.5 rounded-xl border border-white/10 bg-white/5 px-3 py-1.5 font-sans text-xs font-semibold text-zinc-300 transition hover:bg-white/10 hover:text-white active:scale-95 disabled:opacity-50"
            >
              <RefreshCw className={cn("h-3.5 w-3.5", refetchingLive && "animate-spin")} />
              <span>Refresh</span>
            </button>
          </div>

          {loadingLive ? (
            <div className="flex justify-center py-16">
              <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
            </div>
          ) : streams.length === 0 ? (
            <div className="flex flex-col items-center justify-center rounded-[28px] border border-white/10 bg-[#141420]/70 p-10 text-center shadow-xl backdrop-blur-xl">
              <div className="flex h-16 w-16 items-center justify-center rounded-2xl border border-white/10 bg-[#1e1e2d] text-zinc-400 shadow-inner">
                <Radio className="h-7 w-7 text-zinc-400" />
              </div>
              <h3 className="mt-4 font-sans text-base font-bold text-white">
                No one is live right now
              </h3>
              <p className="mt-1 text-xs text-zinc-400">
                Be the first — tap Go Live below
              </p>
            </div>
          ) : (
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {streams.map((s) => (
                <Link
                  key={s.id}
                  href={`/live/${s.id}`}
                  className="group relative overflow-hidden rounded-[24px] border border-white/10 bg-[#161622] shadow-xl transition hover:border-brand-purple/50 active:scale-99"
                >
                  <div className="relative aspect-video bg-[#12121e]">
                    {s.thumbnailUrl ? (
                      <img
                        src={cloudinaryUrl(s.thumbnailUrl, "c_fill,w_600,h_340")}
                        alt=""
                        className="h-full w-full object-cover transition group-hover:scale-105"
                      />
                    ) : (
                      <div className="flex h-full w-full items-center justify-center bg-[#181826]">
                        <Radio className="h-10 w-10 text-brand-purple animate-pulse" />
                      </div>
                    )}
                    <span className="absolute left-3 top-3 flex items-center gap-1.5 rounded-full bg-red-600 px-2.5 py-1 font-sans text-xs font-bold text-white shadow-lg">
                      <Radio className="h-3 w-3 animate-pulse" /> LIVE
                    </span>
                    <span className="absolute bottom-3 left-3 flex items-center gap-1 rounded-full bg-black/60 px-2.5 py-1 font-sans text-[11px] font-semibold text-white backdrop-blur-md">
                      <Users className="h-3 w-3" /> {s.viewerCount ?? 0}
                    </span>
                  </div>
                  <div className="p-3.5">
                    <p className="font-sans text-sm font-bold text-white line-clamp-1">{s.title}</p>
                    <p className="text-xs text-zinc-400">@{s.host?.username ?? s.hostId}</p>
                  </div>
                </Link>
              ))}
            </div>
          )}
        </section>

        <section className="mb-8">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="font-sans text-xs font-bold uppercase tracking-wider text-zinc-300">
              Saved Replays
            </h2>
            <div className="flex items-center gap-2">
              <Link
                href="/live/replays"
                className="font-sans text-xs font-bold text-brand-purple hover:underline"
              >
                View all
              </Link>
              <button
                type="button"
                onClick={() => refetchReplays()}
                disabled={refetchingReplays}
                className="flex items-center gap-1.5 rounded-xl border border-white/10 bg-white/5 px-3 py-1.5 font-sans text-xs font-semibold text-zinc-300 transition hover:bg-white/10 hover:text-white active:scale-95 disabled:opacity-50"
              >
                <RefreshCw className={cn("h-3.5 w-3.5", refetchingReplays && "animate-spin")} />
                <span>Refresh</span>
              </button>
            </div>
          </div>

          {loadingReplays ? (
            <div className="flex justify-center py-16">
              <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
            </div>
          ) : replays.length === 0 ? (
            <div className="rounded-[28px] border border-white/10 bg-[#141420]/70 p-8 text-center text-xs text-zinc-500">
              No saved replays found yet
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-3.5 md:grid-cols-3 lg:grid-cols-4">
              {replays.map((r) => (
                <Link
                  key={r.id}
                  href={`/live/replay/${r.id}`}
                  className="group relative flex flex-col overflow-hidden rounded-[24px] border border-white/10 bg-[#161622] shadow-xl transition hover:border-brand-purple/50 active:scale-98"
                >
                  <div className="relative aspect-[3/4] w-full bg-[#101018] flex items-center justify-center overflow-hidden">
                    {r.thumbnailUrl ? (
                      <img
                        src={cloudinaryUrl(r.thumbnailUrl, "c_fill,w_360,h_480")}
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
        </section>

        <aside aria-label="Go live action" className="fixed bottom-6 right-6 z-40">
          <Link
            href="/live/setup"
            className="flex items-center gap-2 rounded-full brand-gradient px-5 py-3.5 font-sans text-xs font-bold text-white shadow-2xl shadow-brand-purple/40 transition hover:scale-105 active:scale-95"
          >
            <Plus className="h-5 w-5 stroke-[2.5]" />
            <span>Go Live</span>
          </Link>
        </aside>
      </div>
    </AuthGuard>
  );
}
