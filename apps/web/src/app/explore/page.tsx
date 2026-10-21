"use client";

import { useQuery, useInfiniteQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useState, useEffect, useTransition } from "react";
import { AuthGuard } from "@/components/auth-guard";
import { FeedGrid, TabBar } from "@/components/feed-card";
import { Input } from "@/components/ui/input";
import {
  getClipsFeed,
  getForYouFeed,
  getLiveFeed,
  getOnlineUsers,
  getTrendingHashtags,
  searchExplore,
} from "@/lib/api/feed";
import type { FeedItem, XLiveUser } from "@/lib/types";
import { cloudinaryUrl, handleLabel, publicHandle } from "@/lib/utils";
import {
  Search,
  X,
  Loader2,
  Users,
  Flame,
  Hash,
  Radio,
  Film,
  MessageSquare,
  ArrowRight,
  SearchX,
} from "lucide-react";

const baseTabs = [
  { id: "all", label: "For You" },
  { id: "live", label: "Live Now" },
  { id: "clips", label: "Clips" },
  { id: "people", label: "People" },
  { id: "trending", label: "Tags" },
];

export default function ExplorePage() {
  const [tab, setTab] = useState("all");
  const [query, setQuery] = useState("");
  const [debouncedQuery, setDebouncedQuery] = useState("");
  const [, startTransition] = useTransition();

  useEffect(() => {
    const timer = setTimeout(() => {
      startTransition(() => {
        setDebouncedQuery(query.trim());
      });
    }, 250);
    return () => clearTimeout(timer);
  }, [query]);

  const isSearching = debouncedQuery.length > 0;

  const searchQuery = useQuery({
    queryKey: ["explore-search", debouncedQuery],
    queryFn: () => searchExplore(debouncedQuery),
    enabled: isSearching,
    staleTime: 1000 * 30,
  });

  const feedQuery = useInfiniteQuery({
    queryKey: ["explore-feed", tab],
    queryFn: async ({ pageParam = 1 }) => {
      if (tab === "live") return getLiveFeed(pageParam);
      if (tab === "clips") return getClipsFeed(pageParam);
      return getForYouFeed(pageParam);
    },
    initialPageParam: 1,
    getNextPageParam: (lastPage, allPages) => {
      if (lastPage?.hasMore && lastPage.items.length > 0) {
        return allPages.length + 1;
      }
      return undefined;
    },
    enabled: !isSearching && (tab === "all" || tab === "live" || tab === "clips"),
    staleTime: 0,
    refetchOnMount: "always",
    refetchOnWindowFocus: true,
  });

  const trendingTagsQuery = useQuery({
    queryKey: ["trending-hashtags"],
    queryFn: getTrendingHashtags,
    staleTime: 1000 * 60,
  });

  const onlineUsersQuery = useQuery({
    queryKey: ["online-creators"],
    queryFn: () => getOnlineUsers(24),
    enabled: !isSearching && tab === "people",
    staleTime: 1000 * 60,
  });

  const searchResults = searchQuery.data;
  const searchLoading = isSearching && searchQuery.isLoading;

  const tabs = baseTabs.map((t) =>
    t.id === "all" && isSearching ? { id: "all", label: "All Results" } : t
  );

  const trendingTags = trendingTagsQuery.data?.tags ?? [];
  const feedItems: FeedItem[] = feedQuery.data?.pages.flatMap((p) => p.items) ?? [];
  const onlineUsers: XLiveUser[] = onlineUsersQuery.data?.users ?? [];

  function handleClear() {
    setQuery("");
    setDebouncedQuery("");
  }

  function handleTagClick(tagName: string) {
    const cleanTag = tagName.replace(/^#/, "");
    setTab("all");
    setQuery(`#${cleanTag}`);
    setDebouncedQuery(`#${cleanTag}`);
  }

  return (
    <AuthGuard>
      <div className="mx-auto max-w-6xl pb-20">
        <div className="sticky top-0 z-20 border-b border-border/80 bg-surface/90 p-4 backdrop-blur-2xl">
          <div className="relative flex items-center">
            <Search className="pointer-events-none absolute left-3.5 h-4 w-4 text-muted" />
            <Input
              type="text"
              placeholder="Search creators, hashtags, content…"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  setDebouncedQuery(query.trim());
                } else if (e.key === "Escape") {
                  handleClear();
                }
              }}
              className="h-12 rounded-2xl border-border/60 bg-surface-hover/80 pl-10 pr-12 text-sm text-foreground placeholder:text-muted focus-visible:border-brand-purple focus-visible:ring-2 focus-visible:ring-brand-purple/30 transition-all"
            />
            <div className="absolute right-3.5 flex items-center gap-2">
              {searchLoading ? (
                <Loader2 className="h-4 w-4 animate-spin text-brand-purple" />
              ) : query.length > 0 ? (
                <button
                  type="button"
                  onClick={handleClear}
                  className="flex h-6 w-6 items-center justify-center rounded-full bg-white/10 text-muted transition hover:bg-white/20 hover:text-white"
                  title="Clear search"
                >
                  <X className="h-3.5 w-3.5" />
                </button>
              ) : null}
            </div>
          </div>

          {!isSearching && trendingTags.length > 0 ? (
            <div className="mt-3 flex items-center gap-1.5 overflow-x-auto no-scrollbar py-0.5">
              <span className="flex items-center gap-1 text-[11px] font-semibold text-muted uppercase tracking-wider shrink-0 mr-1">
                <Flame className="h-3 w-3 text-orange-500" /> Trending:
              </span>
              {trendingTags.slice(0, 8).map((t) => (
                <button
                  key={t.tag}
                  type="button"
                  onClick={() => handleTagClick(t.tag)}
                  className="inline-flex shrink-0 items-center gap-1 rounded-xl border border-white/10 bg-white/[0.04] px-2.5 py-1 text-xs font-medium text-zinc-300 transition hover:border-brand-purple/40 hover:bg-brand-purple/10 hover:text-brand-purple"
                >
                  <Hash className="h-3 w-3 opacity-60" />
                  <span>{t.tag}</span>
                </button>
              ))}
            </div>
          ) : null}
        </div>

        <TabBar tabs={tabs} active={tab} onChange={setTab} />

        {isSearching ? (
          searchLoading ? (
            <div className="flex flex-col items-center justify-center py-28 text-center">
              <div className="h-10 w-10 animate-spin rounded-full border-2 border-brand-purple border-t-transparent" />
              <p className="mt-4 text-xs font-medium text-muted">Searching creators, hashtags, content…</p>
            </div>
          ) : !searchResults ||
            (searchResults.users.length === 0 &&
              searchResults.videos.length === 0 &&
              searchResults.clips.length === 0 &&
              searchResults.streams.length === 0 &&
              searchResults.hashtags.length === 0 &&
              searchResults.groups.length === 0) ? (
            <div className="flex flex-col items-center justify-center py-24 px-4 text-center">
              <div className="flex h-16 w-16 items-center justify-center rounded-3xl border border-white/10 bg-surface-hover/80 text-muted shadow-2xl">
                <SearchX className="h-8 w-8 text-brand-purple/80" />
              </div>
              <h3 className="mt-5 font-display text-lg font-bold text-white">
                No results for &ldquo;{debouncedQuery}&rdquo;
              </h3>
              <p className="mt-1.5 max-w-sm text-xs text-zinc-400">
                We couldn&apos;t find any creators, content, or hashtags matching your search.
              </p>
              <button
                type="button"
                onClick={handleClear}
                className="mt-6 rounded-2xl brand-gradient px-5 py-2.5 text-xs font-bold text-white shadow-lg shadow-brand-purple/20 transition hover:opacity-95 active:scale-95"
              >
                Clear Search
              </button>
            </div>
          ) : tab === "people" ? (
            <div className="p-4">
              {!searchResults.users.length ? (
                <div className="flex flex-col items-center justify-center py-24 text-center">
                  <Users className="h-8 w-8 text-muted/60" />
                  <p className="mt-3 font-semibold text-white">No creators matching &ldquo;{debouncedQuery}&rdquo;</p>
                </div>
              ) : (
                <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 md:grid-cols-3">
                  {searchResults.users.map((u) => (
                    <CreatorCard key={u.id} user={u} />
                  ))}
                </div>
              )}
            </div>
          ) : tab === "live" ? (
            <div className="p-4">
              {!searchResults.streams.length ? (
                <div className="flex flex-col items-center justify-center py-24 text-center">
                  <Radio className="h-8 w-8 text-muted/60" />
                  <p className="mt-3 font-semibold text-white">No live streams matching &ldquo;{debouncedQuery}&rdquo;</p>
                </div>
              ) : (
                <FeedGrid items={searchResults.streams} empty="No live streams found" />
              )}
            </div>
          ) : tab === "clips" ? (
            <div className="p-4">
              {!searchResults.clips.length ? (
                <div className="flex flex-col items-center justify-center py-24 text-center">
                  <Film className="h-8 w-8 text-muted/60" />
                  <p className="mt-3 font-semibold text-white">No clips matching &ldquo;{debouncedQuery}&rdquo;</p>
                </div>
              ) : (
                <FeedGrid items={searchResults.clips} empty="No clips found" />
              )}
            </div>
          ) : tab === "trending" ? (
            <div className="p-6">
              {!searchResults.hashtags.length ? (
                <div className="flex flex-col items-center justify-center py-24 text-center">
                  <Hash className="h-8 w-8 text-muted/60" />
                  <p className="mt-3 font-semibold text-white">No hashtags matching &ldquo;{debouncedQuery}&rdquo;</p>
                </div>
              ) : (
                <div className="flex flex-wrap gap-2.5">
                  {searchResults.hashtags.map((t) => (
                    <Link
                      key={t.tag}
                      href={`/hashtags/${encodeURIComponent(t.tag)}`}
                      className="flex items-center gap-1.5 rounded-2xl border border-border/70 bg-surface/70 px-4 py-2.5 text-xs font-semibold text-foreground transition hover:border-brand-purple/50 hover:bg-surface-hover hover:text-brand-purple"
                    >
                      <Hash className="h-3.5 w-3.5 opacity-60" />
                      <span>{t.tag}</span>
                      {t.count ? (
                        <span className="ml-1 text-[10px] text-muted font-normal">({t.count})</span>
                      ) : null}
                    </Link>
                  ))}
                </div>
              )}
            </div>
          ) : (
            <div className="space-y-8 p-4">
              {searchResults.users.length > 0 ? (
                <div>
                  <div className="mb-3 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Users className="h-4 w-4 text-brand-purple" />
                      <h2 className="font-display text-base font-bold text-white">
                        Creators ({searchResults.users.length})
                      </h2>
                    </div>
                    {searchResults.users.length > 3 ? (
                      <button
                        type="button"
                        onClick={() => setTab("people")}
                        className="flex items-center gap-1 text-xs font-semibold text-brand-purple transition hover:underline"
                      >
                        <span>See all</span>
                        <ArrowRight className="h-3.5 w-3.5" />
                      </button>
                    ) : null}
                  </div>
                  <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2 md:grid-cols-3">
                    {searchResults.users.slice(0, 6).map((u) => (
                      <CreatorCard key={u.id} user={u} />
                    ))}
                  </div>
                </div>
              ) : null}

              {searchResults.streams.length > 0 ? (
                <div>
                  <div className="mb-3 flex items-center gap-2">
                    <Radio className="h-4 w-4 text-red-500 animate-pulse" />
                    <h2 className="font-display text-base font-bold text-white">
                      Live Streams ({searchResults.streams.length})
                    </h2>
                  </div>
                  <FeedGrid items={searchResults.streams} />
                </div>
              ) : null}

              {searchResults.videos.length > 0 || searchResults.clips.length > 0 ? (
                <div>
                  <div className="mb-3 flex items-center gap-2">
                    <Film className="h-4 w-4 text-brand-sky" />
                    <h2 className="font-display text-base font-bold text-white">
                      Content ({searchResults.videos.length + searchResults.clips.length})
                    </h2>
                  </div>
                  <FeedGrid items={[...searchResults.videos, ...searchResults.clips]} />
                </div>
              ) : null}

              {searchResults.hashtags.length > 0 ? (
                <div>
                  <div className="mb-3 flex items-center gap-2">
                    <Hash className="h-4 w-4 text-brand-purple" />
                    <h2 className="font-display text-base font-bold text-white">Hashtags</h2>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {searchResults.hashtags.map((t) => (
                      <Link
                        key={t.tag}
                        href={`/hashtags/${encodeURIComponent(t.tag)}`}
                        className="flex items-center gap-1.5 rounded-2xl border border-white/10 bg-surface/70 px-4 py-2.5 text-xs font-semibold text-foreground transition hover:border-brand-purple/50 hover:bg-surface-hover hover:text-brand-purple"
                      >
                        <Hash className="h-3.5 w-3.5 opacity-60" />
                        <span>{t.tag}</span>
                        {t.count ? (
                          <span className="ml-1 text-[10px] text-muted font-normal">({t.count})</span>
                        ) : null}
                      </Link>
                    ))}
                  </div>
                </div>
              ) : null}

              {searchResults.groups.length > 0 ? (
                <div>
                  <div className="mb-3 flex items-center gap-2">
                    <MessageSquare className="h-4 w-4 text-emerald-400" />
                    <h2 className="font-display text-base font-bold text-white">Groups</h2>
                  </div>
                  <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2 md:grid-cols-3">
                    {searchResults.groups.map((g) => (
                      <Link
                        key={g.id}
                        href={`/groups/${g.id}`}
                        className="flex items-center gap-3.5 rounded-2xl border border-white/10 bg-surface/70 p-3.5 transition hover:border-brand-purple/40 hover:bg-surface-hover"
                      >
                        {g.avatarUrl ? (
                          <img
                            src={cloudinaryUrl(g.avatarUrl, "c_fill,w_96,h_96")}
                            alt=""
                            className="h-11 w-11 rounded-2xl object-cover ring-1 ring-border"
                          />
                        ) : (
                          <div className="flex h-11 w-11 items-center justify-center rounded-2xl brand-gradient font-display text-sm font-bold text-white">
                            {g.name[0]?.toUpperCase() ?? "G"}
                          </div>
                        )}
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-semibold text-white">{g.name}</p>
                          <p className="text-xs text-muted">
                            {g.memberCount !== undefined ? `${g.memberCount} members` : "Community"}
                          </p>
                        </div>
                      </Link>
                    ))}
                  </div>
                </div>
              ) : null}
            </div>
          )
        ) : tab === "people" ? (
          <div className="p-4">
            {onlineUsersQuery.isLoading ? (
              <div className="flex justify-center py-20">
                <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
              </div>
            ) : !onlineUsers.length ? (
              <div className="flex flex-col items-center justify-center py-24 text-center">
                <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-surface-hover text-muted shadow-inner">
                  <Users className="h-6 w-6 opacity-60" />
                </div>
                <p className="mt-4 font-display text-base font-semibold text-white">No people to discover yet</p>
                <p className="mt-1 text-xs text-muted">Search above by name or username to find creators to follow</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2 md:grid-cols-3">
                {onlineUsers.map((u) => (
                  <CreatorCard key={u.id} user={u} />
                ))}
              </div>
            )}
          </div>
        ) : tab === "trending" ? (
          <div className="p-6">
            <div className="mb-4 flex items-center gap-2">
              <Flame className="h-5 w-5 text-orange-500" />
              <h2 className="font-display text-base font-bold text-white">Trending Hashtags</h2>
            </div>
            {trendingTagsQuery.isLoading ? (
              <div className="flex justify-center py-20">
                <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
              </div>
            ) : !trendingTags.length ? (
              <div className="flex flex-col items-center justify-center py-24 text-center">
                <Hash className="h-8 w-8 text-muted/60" />
                <p className="mt-3 font-semibold text-white">No trending hashtags yet</p>
              </div>
            ) : (
              <div className="flex flex-wrap gap-2.5">
                {trendingTags.map((t) => (
                  <Link
                    key={t.tag}
                    href={`/hashtags/${encodeURIComponent(t.tag)}`}
                    className="flex items-center gap-1.5 rounded-2xl border border-border/70 bg-surface/70 px-4 py-2.5 text-xs font-semibold text-foreground transition hover:border-brand-purple/50 hover:bg-surface-hover hover:text-brand-purple"
                  >
                    <Hash className="h-3.5 w-3.5 opacity-60" />
                    <span>{t.tag}</span>
                    {t.count ? (
                      <span className="ml-1 text-[10px] text-muted font-normal">({t.count})</span>
                    ) : null}
                  </Link>
                ))}
              </div>
            )}
          </div>
        ) : feedQuery.isLoading ? (
          <div className="flex justify-center py-20">
            <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
          </div>
        ) : (
          <FeedGrid
            items={feedItems}
            empty="Nothing found in this section"
            hasMore={Boolean(feedQuery.hasNextPage)}
            isFetchingNextPage={feedQuery.isFetchingNextPage}
            onLoadMore={() => feedQuery.fetchNextPage()}
            loadMoreItems={async () => {
              const res = await feedQuery.fetchNextPage();
              return res.data?.pages.flatMap((p) => p.items) ?? [];
            }}
          />
        )}
      </div>
    </AuthGuard>
  );
}

function CreatorCard({ user }: { user: XLiveUser }) {
  const handle = publicHandle(user);
  const name = user.displayName?.trim() || "";
  const title = name || (handle ? `@${handle}` : handleLabel(user));
  const initial = (name || handle || "U").charAt(0).toUpperCase();
  return (
    <Link
      href={`/profile/${user.id}`}
      className="flex items-center gap-3.5 rounded-2xl border border-white/10 bg-surface/80 p-3.5 shadow-sm transition hover:border-brand-purple/50 hover:bg-surface-hover hover:shadow-lg hover:shadow-brand-purple/10 active:scale-[0.99]"
    >
      {user.avatarUrl ? (
        <img
          src={cloudinaryUrl(user.avatarUrl, "c_fill,w_96,h_96,g_face")}
          alt=""
          className="h-12 w-12 rounded-2xl object-cover ring-1 ring-border shrink-0"
        />
      ) : (
        <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl brand-gradient font-display text-base font-bold text-white shadow-md">
          {initial}
        </div>
      )}
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-bold text-white">{title}</p>
        {handle && name && name.toLowerCase() !== handle.toLowerCase() ? (
          <p className="truncate text-xs text-muted">{handleLabel(user)}</p>
        ) : user.bio ? (
          <p className="mt-1 line-clamp-1 text-[11px] text-zinc-400">{user.bio}</p>
        ) : null}
      </div>
    </Link>
  );
}
