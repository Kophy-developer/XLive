"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { getClipMarketplace } from "@/lib/api/misc";

export default function MarketplacePage() {
  const { data, isLoading } = useQuery({
    queryKey: ["marketplace"],
    queryFn: () => getClipMarketplace(),
  });

  const listings = (data as { listings?: { id: string; clipId?: string; title?: string; price?: number }[] })?.listings ?? [];

  return (
    <AuthGuard>
      <PageHeader title="Clip marketplace" backHref="/explore" />
      {isLoading ? (
        <div className="flex justify-center py-20"><div className="h-8 w-8 animate-pulse rounded-full brand-gradient" /></div>
      ) : (
        <div className="divide-y divide-border">
          {listings.map((l) => (
            <Link key={l.id} href={`/media/${l.clipId ?? l.id}`} className="flex items-center justify-between p-4 hover:bg-border/10">
              <span>{l.title ?? l.id}</span>
              <span className="text-accent">{l.price ?? "—"}</span>
            </Link>
          ))}
          {!listings.length ? <p className="p-6 text-muted">No listings available</p> : null}
        </div>
      )}
    </AuthGuard>
  );
}
