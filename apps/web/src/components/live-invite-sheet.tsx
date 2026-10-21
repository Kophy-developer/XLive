"use client";

import { useEffect, useMemo, useState } from "react";
import {
  getUserFollowers,
  getUserFollowing,
  sendStreamInvite,
} from "@/lib/api/streams";
import type { XLiveUser } from "@/lib/types";
import { cloudinaryUrl, cn, publicHandle } from "@/lib/utils";
import { Search, UserPlus, Users, X } from "lucide-react";

type Tab = "followers" | "following";

export function LiveInviteSheet({
  streamId,
  hostUserId,
  allowCohost,
  open,
  onClose,
}: {
  streamId: string;
  hostUserId: string;
  allowCohost: boolean;
  open: boolean;
  onClose: () => void;
}) {
  const [tab, setTab] = useState<Tab>("followers");
  const [people, setPeople] = useState<XLiveUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [inviteAsCohost, setInviteAsCohost] = useState(false);
  const [splitPercent, setSplitPercent] = useState(20);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [sent, setSent] = useState<Set<string>>(new Set());
  const [error, setError] = useState("");

  useEffect(() => {
    if (!open || !hostUserId) return;
    let cancelled = false;
    setLoading(true);
    setError("");
    const load = tab === "followers" ? getUserFollowers(hostUserId, 1, 40) : getUserFollowing(hostUserId, 1, 40);
    load
      .then((res) => {
        if (!cancelled) setPeople(res.users.filter((u) => u.id && u.id !== hostUserId));
      })
      .catch(() => {
        if (!cancelled) setPeople([]);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [open, hostUserId, tab]);

  useEffect(() => {
    if (!allowCohost) setInviteAsCohost(false);
  }, [allowCohost]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return people;
    return people.filter((p) => {
      const name = `${p.displayName || ""} ${p.username || ""}`.toLowerCase();
      return name.includes(q);
    });
  }, [people, query]);

  async function invite(person: XLiveUser) {
    if (!person.id || busyId) return;
    setBusyId(person.id);
    setError("");
    try {
      const asCohost = allowCohost && inviteAsCohost;
      await sendStreamInvite(streamId, person.id, {
        role: asCohost ? "cohost" : "viewer",
        earningsSplitPercent: asCohost ? splitPercent : undefined,
      });
      setSent((prev) => new Set(prev).add(person.id));
    } catch (e) {
      setError((e as Error).message || "Could not send invite");
    } finally {
      setBusyId(null);
    }
  }

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[80] flex items-end justify-center bg-black/70 p-3 sm:items-center">
      <button type="button" className="absolute inset-0" aria-label="Close" onClick={onClose} />
      <div className="relative z-10 flex max-h-[85vh] w-full max-w-md flex-col overflow-hidden rounded-3xl border border-white/10 bg-[#141420] shadow-2xl">
        <div className="flex items-center justify-between border-b border-white/10 px-4 py-3">
          <h2 className="font-sans text-base font-extrabold text-white">Invite people</h2>
          <button
            type="button"
            onClick={onClose}
            className="flex h-9 w-9 items-center justify-center rounded-full bg-white/5 text-white hover:bg-white/10"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="space-y-3 border-b border-white/10 p-4">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-zinc-400" />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search people"
              className="w-full rounded-xl border border-white/10 bg-[#12121e] py-2.5 pl-9 pr-3 text-sm text-white outline-none focus:border-brand-purple/50"
            />
          </div>
          <div className="flex gap-2">
            {(["followers", "following"] as Tab[]).map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => setTab(t)}
                className={cn(
                  "rounded-full px-3 py-1.5 text-xs font-bold capitalize",
                  tab === t ? "bg-brand-purple text-white" : "bg-white/5 text-zinc-300"
                )}
              >
                {t}
              </button>
            ))}
          </div>
          {allowCohost ? (
            <label className="flex items-start justify-between gap-3 rounded-2xl border border-white/10 bg-[#12121e] p-3">
              <div>
                <p className="flex items-center gap-1.5 text-xs font-bold text-white">
                  <Users className="h-3.5 w-3.5 text-brand-purple" />
                  Invite as co-host
                </p>
                <p className="mt-1 text-[11px] text-zinc-400">Private streams only. Split earnings with co-hosts.</p>
              </div>
              <input
                type="checkbox"
                checked={inviteAsCohost}
                onChange={(e) => setInviteAsCohost(e.target.checked)}
                className="mt-1 h-5 w-5 accent-brand-purple"
              />
            </label>
          ) : null}
          {allowCohost && inviteAsCohost ? (
            <div className="rounded-2xl border border-white/10 bg-[#12121e] p-3">
              <div className="mb-2 flex items-center justify-between text-xs">
                <span className="font-bold text-white">Each co-host</span>
                <span className="font-extrabold text-brand-purple">{splitPercent}%</span>
              </div>
              <input
                type="range"
                min={5}
                max={30}
                step={1}
                value={splitPercent}
                onChange={(e) => setSplitPercent(Number(e.target.value))}
                className="w-full accent-brand-purple"
              />
            </div>
          ) : null}
          {error ? <p className="text-xs font-semibold text-red-400">{error}</p> : null}
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto p-2">
          {loading ? (
            <div className="flex justify-center py-12">
              <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
            </div>
          ) : filtered.length === 0 ? (
            <p className="py-12 text-center text-sm text-zinc-400">No people found</p>
          ) : (
            <ul className="space-y-1">
              {filtered.map((person) => {
                const already = sent.has(person.id);
                return (
                  <li key={person.id} className="flex items-center gap-3 rounded-2xl px-3 py-2.5 hover:bg-white/5">
                    {person.avatarUrl ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={cloudinaryUrl(person.avatarUrl)}
                        alt=""
                        className="h-10 w-10 rounded-full object-cover"
                      />
                    ) : (
                      <div className="flex h-10 w-10 items-center justify-center rounded-full bg-white/10 text-xs font-bold text-white">
                        {(person.displayName || person.username || "?").slice(0, 1).toUpperCase()}
                      </div>
                    )}
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-bold text-white">{person.displayName || person.username}</p>
                      <p className="truncate text-xs text-zinc-400">{publicHandle(person)}</p>
                    </div>
                    <button
                      type="button"
                      disabled={already || busyId === person.id}
                      onClick={() => void invite(person)}
                      className={cn(
                        "inline-flex items-center gap-1 rounded-xl px-3 py-1.5 text-xs font-bold transition",
                        already
                          ? "bg-white/10 text-zinc-400"
                          : "brand-gradient text-white active:scale-95"
                      )}
                    >
                      <UserPlus className="h-3.5 w-3.5" />
                      {already ? "Invited" : inviteAsCohost && allowCohost ? "Invite co-host" : "Invite"}
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}
