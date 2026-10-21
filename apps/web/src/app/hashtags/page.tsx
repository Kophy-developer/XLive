"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { AuthGuard } from "@/components/auth-guard";
import { getTrendingHashtags } from "@/lib/api/feed";

export default function HashtagsPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["trending-hashtags"],
    queryFn: getTrendingHashtags,
  });

  const tags = data?.tags ?? [];

  return (
    <AuthGuard>
      <div className="border-b border-border p-4">
        <h1 className="font-display text-xl font-semibold">Hashtags</h1>
      </div>
      {isLoading ? (
        <div className="flex justify-center py-20"><div className="h-8 w-8 animate-pulse rounded-full brand-gradient" /></div>
      ) : (
        <div className="flex flex-wrap gap-2 p-4">
          {tags.map((t) => (
            <Link
              key={t.tag}
              href={`/hashtags/${encodeURIComponent(t.tag)}`}
              className="rounded-full border border-border px-4 py-2 text-sm hover:border-accent/50"
            >
              #{t.tag}
            </Link>
          ))}
        </div>
      )}
    </AuthGuard>
  );
}
