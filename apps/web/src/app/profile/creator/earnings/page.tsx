"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { getCreatorEarnings, CreatorEarningsData } from "@/lib/api/creator";
import { ChevronRight } from "lucide-react";

export default function CreatorEarningsPage() {
  const [range, setRange] = useState<"today" | "week" | "month">("today");

  const { data } = useQuery<CreatorEarningsData>({
    queryKey: ["creator-earnings", range],
    queryFn: () => getCreatorEarnings(range),
  });

  const balance = data?.balance ?? 0;
  const withdrawn = data?.totalWithdrawn ?? 0;
  const earnedInRange = data?.totalEarnedInRange ?? 0;
  const breakdown = data?.breakdown ?? {
    streamGifts: 0,
    privateStreams: 0,
    clips: 0,
    posts: 0,
    subscriptions: 0,
  };

  return (
    <AuthGuard>
      <PageHeader title="Earnings & Withdrawals" backHref="/profile/creator" />

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

        <div className="grid grid-cols-3 gap-2.5">
          <div className="rounded-2xl border border-white/10 bg-[#141420]/80 p-3.5 backdrop-blur-xl">
            <p className="text-[10px] font-medium text-zinc-400">Available balance</p>
            <p className="mt-1 font-sans text-sm font-bold text-white tracking-tight tabular-nums">
              USD {balance.toFixed(2)}
            </p>
          </div>
          <div className="rounded-2xl border border-white/10 bg-[#141420]/80 p-3.5 backdrop-blur-xl">
            <p className="text-[10px] font-medium text-zinc-400">Withdrawn (lifetime)</p>
            <p className="mt-1 font-sans text-sm font-bold text-white tracking-tight tabular-nums">
              USD {withdrawn.toFixed(2)}
            </p>
          </div>
          <div className="rounded-2xl border border-white/10 bg-[#141420]/80 p-3.5 backdrop-blur-xl">
            <p className="text-[10px] font-medium text-zinc-400">Earned in range</p>
            <p className="mt-1 font-sans text-sm font-bold text-white tracking-tight tabular-nums">
              USD {earnedInRange.toFixed(2)}
            </p>
          </div>
        </div>

        <div className="rounded-3xl border border-white/10 bg-[#141420]/80 p-5 backdrop-blur-xl divide-y divide-white/10 shadow-xl">
          <div className="flex items-center justify-between pb-3 text-xs">
            <span className="font-medium text-zinc-400">Stream gifts</span>
            <span className="font-bold text-white tracking-tight tabular-nums">USD {(breakdown.streamGifts ?? 0).toFixed(2)}</span>
          </div>
          <div className="flex items-center justify-between py-3 text-xs">
            <span className="font-medium text-zinc-400">Private streams</span>
            <span className="font-bold text-white tracking-tight tabular-nums">USD {(breakdown.privateStreams ?? 0).toFixed(2)}</span>
          </div>
          <div className="flex items-center justify-between py-3 text-xs">
            <span className="font-medium text-zinc-400">Clips</span>
            <span className="font-bold text-white tracking-tight tabular-nums">USD {(breakdown.clips ?? 0).toFixed(2)}</span>
          </div>
          <div className="flex items-center justify-between py-3 text-xs">
            <span className="font-medium text-zinc-400">Posts</span>
            <span className="font-bold text-white tracking-tight tabular-nums">USD {(breakdown.posts ?? 0).toFixed(2)}</span>
          </div>
          <div className="flex items-center justify-between pt-3 text-xs">
            <span className="font-medium text-zinc-400">Subscriptions</span>
            <span className="font-bold text-white tracking-tight tabular-nums">USD {(breakdown.subscriptions ?? 0).toFixed(2)}</span>
          </div>
        </div>

        <div className="space-y-2">
          <h3 className="px-1 text-xs font-bold uppercase tracking-wider text-zinc-400">
            Manage payouts
          </h3>

          <div className="space-y-2">
            <div className="group flex items-center justify-between rounded-3xl border border-white/10 bg-[#141420]/80 p-4 transition hover:border-brand-purple/40 hover:bg-[#181828]">
              <div>
                <p className="font-display text-sm font-bold text-white">Request withdrawal</p>
                <p className="text-xs text-zinc-400">Add a payout method first</p>
              </div>
              <ChevronRight className="h-4 w-4 text-zinc-500 group-hover:text-white" />
            </div>

            <div className="group flex items-center justify-between rounded-3xl border border-white/10 bg-[#141420]/80 p-4 transition hover:border-brand-purple/40 hover:bg-[#181828]">
              <div>
                <p className="font-display text-sm font-bold text-white">Withdrawal history</p>
                <p className="text-xs text-zinc-400">No withdrawals yet</p>
              </div>
              <ChevronRight className="h-4 w-4 text-zinc-500 group-hover:text-white" />
            </div>

            <div className="group flex items-center justify-between rounded-3xl border border-white/10 bg-[#141420]/80 p-4 transition hover:border-brand-purple/40 hover:bg-[#181828]">
              <div>
                <p className="font-display text-sm font-bold text-white">Payout methods</p>
                <p className="text-xs text-zinc-400">Set up bank, crypto, or PayPal</p>
              </div>
              <ChevronRight className="h-4 w-4 text-zinc-500 group-hover:text-white" />
            </div>

            <div className="group flex items-center justify-between rounded-3xl border border-white/10 bg-[#141420]/80 p-4 transition hover:border-brand-purple/40 hover:bg-[#181828]">
              <div>
                <p className="font-display text-sm font-bold text-white">Private stream spending</p>
                <p className="text-xs text-zinc-400">What you paid to join private streams</p>
              </div>
              <ChevronRight className="h-4 w-4 text-zinc-500 group-hover:text-white" />
            </div>
          </div>
        </div>
      </div>
    </AuthGuard>
  );
}
