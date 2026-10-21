"use client";

import { useParams } from "next/navigation";
import { useInfiniteQuery } from "@tanstack/react-query";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { FeedGrid } from "@/components/feed-card";
import { getHashtagFeed } from "@/lib/api/feed";
import type { FeedItem } from "@/lib/types";

export default function HashtagFeedPage() {
  const params = useParams();
  const tag = decodeURIComponent(params.tag as string);

  const {
    data,
    isLoading,
    hasNextPage,
    isFetchingNextPage,
    fetchNextPage,
  } = useInfiniteQuery({
    queryKey: ["hashtag", tag],
    queryFn: ({ pageParam = 1 }) => getHashtagFeed(tag, pageParam),
    initialPageParam: 1,
    getNextPageParam: (lastPage, allPages) => {
      if (lastPage?.hasMore && lastPage.items.length > 0) {
        return allPages.length + 1;
      }
      return undefined;
    },
  });

  const items: FeedItem[] = data?.pages.flatMap((p) => p.items) ?? [];

  return (
    <AuthGuard>
      <PageHeader title={`#${tag}`} backHref="/hashtags" />
      {isLoading ? (
        <div className="flex justify-center py-20"><div className="h-8 w-8 animate-pulse rounded-full brand-gradient" /></div>
      ) : (
        <FeedGrid
          items={items}
          empty="No posts for this hashtag"
          hasMore={Boolean(hasNextPage)}
          isFetchingNextPage={isFetchingNextPage}
          onLoadMore={() => fetchNextPage()}
          loadMoreItems={async () => {
            const res = await fetchNextPage();
            return res.data?.pages.flatMap((p) => p.items) ?? [];
          }}
        />
      )}
    </AuthGuard>
  );
}
