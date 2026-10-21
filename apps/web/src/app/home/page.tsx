"use client";

import { useInfiniteQuery } from "@tanstack/react-query";
import { useState } from "react";
import { AuthGuard } from "@/components/auth-guard";
import { FeedGrid, TabBar } from "@/components/feed-card";
import { getClipsFeed, getFollowingFeed, getForYouFeed, getLiveFeed } from "@/lib/api/feed";
import type { FeedItem } from "@/lib/types";

const tabs = [
  { id: "for-you", label: "For You" },
  { id: "following", label: "Following" },
  { id: "live", label: "Live Streams" },
  { id: "clips", label: "Clips" },
];

export default function HomePage() {
  const [tab, setTab] = useState("for-you");

  const {
    data,
    isLoading,
    error,
    hasNextPage,
    isFetchingNextPage,
    fetchNextPage,
  } = useInfiniteQuery({
    queryKey: ["feed", tab],
    queryFn: async ({ pageParam = 1 }) => {
      if (tab === "following") return getFollowingFeed(pageParam);
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
    staleTime: 0,
    refetchOnMount: "always",
    refetchOnWindowFocus: true,
  });

  const items: FeedItem[] = data?.pages.flatMap((p) => p.items) ?? [];

  return (
    <AuthGuard>
      <div className="mx-auto max-w-7xl">
        <TabBar tabs={tabs} active={tab} onChange={setTab} />
        {isLoading ? (
          <div className="flex justify-center py-24">
            <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
          </div>
        ) : error ? (
          <div className="py-20 text-center text-sm text-red-500">{(error as Error).message}</div>
        ) : (
          <FeedGrid
            items={items}
            empty={
              tab === "live"
                ? "No one is live right now."
                : tab === "following"
                ? "No posts from people you follow yet."
                : "No posts yet in this feed. Check Explore to discover creators."
            }
            hasMore={Boolean(hasNextPage)}
            isFetchingNextPage={isFetchingNextPage}
            onLoadMore={() => fetchNextPage()}
            loadMoreItems={async () => {
              const res = await fetchNextPage();
              return res.data?.pages.flatMap((p) => p.items) ?? [];
            }}
            allowOwnerDelete
          />
        )}
      </div>
    </AuthGuard>
  );
}
