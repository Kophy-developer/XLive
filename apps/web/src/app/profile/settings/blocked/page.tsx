"use client";

import { useQuery } from "@tanstack/react-query";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { getBlocks, unblockUser } from "@/lib/api/misc";
import { ShieldCheck } from "lucide-react";

export default function BlockedUsersPage() {
  const { data, refetch } = useQuery({ queryKey: ["blocks"], queryFn: getBlocks });
  const blocks = (data as { users?: { id: string; username: string; displayName?: string }[] })?.users ?? [];

  return (
    <AuthGuard>
      <PageHeader title="Blocked accounts" backHref="/profile/settings" />

      <div className="mx-auto max-w-md px-4 py-6 pb-24">
        {blocks.length > 0 ? (
          <div className="divide-y divide-white/10 rounded-3xl border border-white/10 bg-[#141420]/80 p-2 backdrop-blur-xl shadow-xl">
            {blocks.map((u) => (
              <div key={u.id} className="flex items-center justify-between p-3.5">
                <div>
                  <p className="text-xs font-bold text-white">@{u.username}</p>
                  {u.displayName ? (
                    <p className="text-[11px] text-zinc-400">{u.displayName}</p>
                  ) : null}
                </div>
                <button
                  type="button"
                  onClick={() => unblockUser(u.id).then(() => refetch())}
                  className="rounded-full border border-white/20 bg-white/5 px-3.5 py-1 text-xs font-semibold text-white transition hover:bg-white/10"
                >
                  Unblock
                </button>
              </div>
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center rounded-3xl border border-white/10 bg-[#141420]/40 py-16 text-center shadow-xl">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-white/5 text-zinc-400">
              <ShieldCheck className="h-7 w-7 text-emerald-400" />
            </div>
            <p className="mt-3 font-display text-sm font-bold text-white">No blocked users</p>
            <p className="mt-1 text-xs text-zinc-400 max-w-xs">
              Accounts you block from chats or profile won&apos;t be able to message you or view your streams
            </p>
          </div>
        )}
      </div>
    </AuthGuard>
  );
}
