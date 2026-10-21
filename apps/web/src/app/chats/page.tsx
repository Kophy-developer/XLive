"use client";

import { useEffect, useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { AuthGuard } from "@/components/auth-guard";
import { AccountChip } from "@/components/account-chip";
import { getChats, getGroups, searchChatHistory, type ChatHistoryHit } from "@/lib/api/chats";
import { cloudinaryUrl, handleLabel, publicHandle } from "@/lib/utils";
import { Users, MessageCircle, PlusCircle, ArrowRight, Search, X, SearchX, Loader2 } from "lucide-react";

export default function ChatsInboxPage() {
  const [query, setQuery] = useState("");
  const [historyHits, setHistoryHits] = useState<ChatHistoryHit[]>([]);
  const [searchingHistory, setSearchingHistory] = useState(false);
  const chatsQuery = useQuery({ queryKey: ["chats"], queryFn: getChats });
  const groupsQuery = useQuery({ queryKey: ["groups"], queryFn: getGroups });

  const chats = chatsQuery.data?.chats;
  const groups = groupsQuery.data?.groups;
  const loading = chatsQuery.isLoading || groupsQuery.isLoading;
  const needle = query.trim().toLowerCase();

  const filteredGroups = useMemo(() => {
    const list = groups ?? [];
    if (!needle) return list;
    return list.filter((g) => {
      const name = (g.name || "").toLowerCase();
      const preview = (g.lastMessage || "").toLowerCase();
      return name.includes(needle) || preview.includes(needle);
    });
  }, [groups, needle]);

  const filteredChats = useMemo(() => {
    const list = chats ?? [];
    if (!needle) return list;
    return list.filter((c) => {
      const handle = publicHandle(c.peer).toLowerCase();
      const preview = (c.lastMessage || "").toLowerCase();
      return handle.includes(needle) || preview.includes(needle);
    });
  }, [chats, needle]);

  const emptySearch = Boolean(needle) && !filteredChats.length && !filteredGroups.length && !historyHits.length && !searchingHistory;

  useEffect(() => {
    if (needle.length < 2) {
      setHistoryHits([]);
      setSearchingHistory(false);
      return;
    }
    const controller = new AbortController();
    setHistoryHits([]);
    setSearchingHistory(true);
    searchChatHistory(
      needle,
      { chats: chats ?? [], groups: groups ?? [] },
      (hit) => {
        if (controller.signal.aborted) return;
        setHistoryHits((prev) => (prev.some((p) => p.id === hit.id) ? prev : [...prev, hit]));
      },
      controller.signal
    )
      .catch(() => {})
      .finally(() => {
        if (!controller.signal.aborted) setSearchingHistory(false);
      });
    return () => controller.abort();
  }, [chats, groups, needle]);

  return (
    <AuthGuard>
      <div className="mx-auto max-w-4xl">
        <div className="sticky top-0 z-20 border-b border-border/80 bg-surface/80 px-4 py-3.5 backdrop-blur-xl">
          <div className="flex items-center justify-between gap-3">
            <div>
              <h1 className="font-display text-xl font-bold tracking-tight">Messages</h1>
              <p className="text-xs text-muted">DMs and group communities</p>
            </div>
            <div className="flex shrink-0 items-center gap-2">
              <Link
                href="/groups/join"
                className="flex items-center gap-1.5 rounded-xl border border-border bg-surface-hover/60 px-3 py-1.5 text-xs font-semibold text-foreground transition hover:border-brand-purple/40 hover:text-brand-purple"
              >
                <PlusCircle className="h-4 w-4" />
                Join group
              </Link>
              <AccountChip className="hidden md:flex" />
            </div>
          </div>
          <div className="relative mt-3">
            <Search className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-zinc-500" />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search usernames and messages…"
              className="h-11 w-full rounded-2xl border border-white/10 bg-white/5 pl-10 pr-10 text-sm text-white outline-none placeholder:text-zinc-500 focus:border-brand-purple/50"
            />
            {query ? (
              <button
                type="button"
                onClick={() => setQuery("")}
                className="absolute right-3 top-1/2 -translate-y-1/2 rounded-full p-1 text-zinc-500 hover:text-white"
                aria-label="Clear search"
              >
                <X className="h-4 w-4" />
              </button>
            ) : null}
          </div>
        </div>

        {loading ? (
          <div className="space-y-3 p-4">
            {[...Array(5)].map((_, i) => (
              <div key={i} className="flex animate-pulse items-center gap-3 rounded-2xl bg-surface/50 p-3">
                <div className="h-12 w-12 rounded-full bg-border/40" />
                <div className="flex-1 space-y-2">
                  <div className="h-4 w-1/3 rounded bg-border/40" />
                  <div className="h-3 w-1/2 rounded bg-border/30" />
                </div>
              </div>
            ))}
          </div>
        ) : emptySearch ? (
          <div className="flex flex-col items-center justify-center py-24 text-center">
            <SearchX className="h-10 w-10 text-zinc-600" />
            <p className="mt-4 font-display text-base font-semibold">No chats match “{query.trim()}”</p>
            <p className="mt-1 text-xs text-muted">Try a username or words from a message</p>
          </div>
        ) : (
          <div className="p-3 space-y-4">
            {filteredGroups.length > 0 ? (
              <div>
                <div className="mb-2 flex items-center gap-1.5 px-2 text-xs font-bold uppercase tracking-wider text-muted">
                  <Users className="h-3.5 w-3.5" /> Groups
                </div>
                <div className="space-y-1">
                  {filteredGroups.map((g) => (
                    <Link
                      key={g.id}
                      href={`/groups/${g.id}?name=${encodeURIComponent(g.name || "Group")}&avatar=${encodeURIComponent(g.avatarUrl || "")}`}
                      className="group flex items-center gap-3.5 rounded-2xl border border-border/40 bg-surface/60 p-3 transition hover:border-brand-purple/40 hover:bg-surface-hover/80"
                    >
                      {g.avatarUrl ? (
                        <img
                          src={cloudinaryUrl(g.avatarUrl, "c_fill,w_96,h_96,g_auto")}
                          alt=""
                          className="h-12 w-12 rounded-2xl object-cover ring-1 ring-border"
                        />
                      ) : (
                        <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-brand-purple/20 to-brand-sky/20 font-display text-base font-bold text-foreground">
                          {g.name[0]?.toUpperCase() ?? "G"}
                        </div>
                      )}
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center justify-between gap-2">
                          <p className="truncate text-sm font-semibold text-foreground group-hover:text-brand-purple">
                            {g.name}
                          </p>
                          <span className="shrink-0 text-[11px] text-muted">
                            {g.memberCount ? `${g.memberCount} members` : ""}
                          </span>
                        </div>
                        <p className="truncate text-xs text-muted">
                          {g.lastMessage || "Active group conversation"}
                        </p>
                      </div>
                      {(g.unreadCount ?? 0) > 0 ? (
                        <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-brand-purple px-1.5 text-[11px] font-bold text-white shadow-sm">
                          {g.unreadCount}
                        </span>
                      ) : (
                        <ArrowRight className="h-4 w-4 opacity-0 transition group-hover:opacity-60" />
                      )}
                    </Link>
                  ))}
                </div>
              </div>
            ) : null}

            <div>
              {filteredGroups.length > 0 ? (
                <div className="mb-2 flex items-center gap-1.5 px-2 text-xs font-bold uppercase tracking-wider text-muted">
                  <MessageCircle className="h-3.5 w-3.5" /> Direct Messages
                </div>
              ) : null}
              {filteredChats.length > 0 ? (
                <div className="space-y-1">
                  {filteredChats.map((c) => {
                    const peerName = handleLabel(c.peer);
                    return (
                      <Link
                        key={c.id}
                        href={`/chats/${c.id}?name=${encodeURIComponent(peerName)}&username=${encodeURIComponent(c.peer?.username || "")}&avatar=${encodeURIComponent(c.peer?.avatarUrl || "")}`}
                        className="group flex items-center gap-3.5 rounded-2xl border border-border/40 bg-surface/60 p-3 transition hover:border-brand-purple/40 hover:bg-surface-hover/80"
                      >
                        {c.peer?.avatarUrl ? (
                          <img
                            src={cloudinaryUrl(c.peer.avatarUrl, "c_fill,w_96,h_96,g_face")}
                            alt=""
                            className="h-12 w-12 rounded-full object-cover ring-1 ring-border"
                          />
                        ) : (
                          <div className="flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-br from-brand-purple/20 to-brand-sky/20 font-display text-sm font-bold text-foreground">
                            {c.peer?.username?.[0]?.toUpperCase() ?? "U"}
                          </div>
                        )}
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center justify-between gap-2">
                            <p className="truncate text-sm font-semibold text-foreground group-hover:text-brand-purple">
                              {peerName}
                            </p>
                          </div>
                          <p className="truncate text-xs text-muted">
                            {c.lastMessage || "Tap to chat"}
                          </p>
                        </div>
                        {(c.unreadCount ?? 0) > 0 ? (
                          <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-brand-purple px-1.5 text-[11px] font-bold text-white shadow-sm">
                            {c.unreadCount}
                          </span>
                        ) : (
                          <ArrowRight className="h-4 w-4 opacity-0 transition group-hover:opacity-60" />
                        )}
                      </Link>
                    );
                  })}
                </div>
              ) : (
                !filteredGroups.length && (
                  <div className="flex flex-col items-center justify-center py-24 text-center">
                    <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-surface-hover/80 text-muted shadow-inner">
                      <MessageCircle className="h-7 w-7 opacity-50" />
                    </div>
                    <p className="mt-4 font-display text-base font-semibold">No conversations yet</p>
                    <p className="mt-1 text-xs text-muted">Start a conversation from a creator profile</p>
                  </div>
                )
              )}
            </div>

            {needle.length >= 2 ? (
              <div>
                <div className="mb-2 flex items-center gap-1.5 px-2 text-xs font-bold uppercase tracking-wider text-muted">
                  <Search className="h-3.5 w-3.5" /> Message matches
                  {searchingHistory ? <Loader2 className="h-3 w-3 animate-spin text-brand-purple" /> : null}
                </div>
                {historyHits.length ? (
                  <div className="space-y-1">
                    {historyHits.map((hit) => (
                      <Link
                        key={hit.id}
                        href={hit.href}
                        className="group flex items-center gap-3.5 rounded-2xl border border-border/40 bg-surface/60 p-3 transition hover:border-brand-purple/40 hover:bg-surface-hover/80"
                      >
                        {hit.avatarUrl ? (
                          <img
                            src={cloudinaryUrl(hit.avatarUrl, "c_fill,w_96,h_96,g_face")}
                            alt=""
                            className="h-11 w-11 rounded-full object-cover ring-1 ring-border"
                          />
                        ) : (
                          <div className="flex h-11 w-11 items-center justify-center rounded-full bg-gradient-to-br from-brand-purple/20 to-brand-sky/20 font-display text-sm font-bold">
                            {hit.title.replace(/^@/, "")[0]?.toUpperCase() ?? "M"}
                          </div>
                        )}
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-semibold text-foreground">{hit.title}</p>
                          <p className="truncate text-xs text-muted">{hit.preview}</p>
                        </div>
                        <ArrowRight className="h-4 w-4 opacity-0 transition group-hover:opacity-60" />
                      </Link>
                    ))}
                  </div>
                ) : searchingHistory ? (
                  <p className="px-2 py-3 text-xs text-muted">Searching older messages…</p>
                ) : (
                  <p className="px-2 py-3 text-xs text-muted">No older messages matched this search</p>
                )}
              </div>
            ) : null}
          </div>
        )}
      </div>
    </AuthGuard>
  );
}
