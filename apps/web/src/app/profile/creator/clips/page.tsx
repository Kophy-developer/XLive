"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { getArchivedClips } from "@/lib/api/creator";
import { Archive } from "lucide-react";
import { cloudinaryUrl } from "@/lib/utils";

export default function CreatorClipsPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["creator-archived-clips"],
    queryFn: () => getArchivedClips(1, 30),
  });

  const clips = data?.docs ?? [];

  return (
    <AuthGuard>
      <PageHeader title="Clip Archive" backHref="/profile/creator" />

      <div className="mx-auto max-w-md px-4 py-6 pb-24">
        {isLoading ? (
          <div className="flex justify-center py-20">
            <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
          </div>
        ) : clips.length > 0 ? (
          <div className="grid grid-cols-2 gap-3">
            {clips.map((clip, i) => {
              const id = String(clip.id || clip._id || i);
              const thumb = clip.thumbnailUrl || clip.previewUrl;
              return (
                <Link
                  key={id}
                  href={`/media/${id}`}
                  className="group relative overflow-hidden rounded-2xl border border-white/10 bg-[#141420]/80 transition hover:border-brand-purple/40"
                >
                  <div className="aspect-[9/16] w-full bg-black/60 overflow-hidden">
                    {thumb ? (
                      <img
                        src={cloudinaryUrl(String(thumb), "c_fill,w_300,h_533")}
                        alt=""
                        className="h-full w-full object-cover transition group-hover:scale-105"
                      />
                    ) : (
                      <div className="flex h-full w-full items-center justify-center text-zinc-500">
                        <Archive className="h-8 w-8" />
                      </div>
                    )}
                  </div>
                  <div className="p-2.5">
                    <p className="text-xs font-bold text-white truncate">
                      {String(clip.name || clip.title || clip.caption || "Archived Clip")}
                    </p>
                  </div>
                </Link>
              );
            })}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center rounded-3xl border border-white/10 bg-[#141420]/40 py-20 text-center shadow-xl">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-white/5 text-zinc-400">
              <Archive className="h-7 w-7" />
            </div>
            <p className="mt-3 font-display text-sm font-bold text-white">No archived clips.</p>
            <p className="mt-1 text-xs text-zinc-400 max-w-xs">
              Collectibles you archive from your public profile will appear here
            </p>
          </div>
        )}
      </div>
    </AuthGuard>
  );
}
