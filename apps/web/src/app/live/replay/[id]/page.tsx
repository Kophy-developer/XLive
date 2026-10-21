"use client";

import { useQuery } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import { AuthGuard } from "@/components/auth-guard";
import { getReplay, getStream } from "@/lib/api/streams";
import { getUserProfile } from "@/lib/api/feed";
import { cloudinaryUrl, handleLabel, playbackVideoUrl, publicHandle } from "@/lib/utils";
import { ArrowLeft, Video } from "lucide-react";

export default function ReplayDetailPage() {
  const params = useParams();
  const router = useRouter();
  const id = params.id as string;

  const { data: replayData, isLoading: loadingReplay, error: replayError } = useQuery({
    queryKey: ["replay", id],
    queryFn: () => getReplay(id),
  });

  const { data: streamData } = useQuery({
    queryKey: ["stream", id],
    queryFn: () => getStream(id),
  });

  const hostId = streamData?.hostId || streamData?.host?.id;
  const { data: hostProfile } = useQuery({
    queryKey: ["replay-host", hostId],
    queryFn: () => getUserProfile(hostId!),
    enabled: Boolean(hostId) && !(publicHandle(streamData?.host) && publicHandle(streamData?.host).toLowerCase() !== "host"),
  });

  const videoUrl = replayData?.replayUrl || streamData?.replayUrl;
  const posterUrl = replayData?.thumbnailUrl || streamData?.thumbnailUrl;
  const title = streamData?.title || replayData?.title || "Live Replay";
  const host = streamData?.host;
  const rawHandle = publicHandle(host);
  const hostHandle =
    rawHandle && rawHandle.toLowerCase() !== "host"
      ? rawHandle
      : publicHandle(hostProfile) || publicHandle(host?.displayName);

  return (
    <AuthGuard>
      <div className="mx-auto max-w-4xl px-4 py-6 md:px-8">
        <header className="mb-6 flex items-center gap-3">
          <button
            type="button"
            onClick={() => router.push("/live")}
            className="flex h-10 w-10 items-center justify-center rounded-2xl border border-white/10 bg-white/5 text-white transition hover:bg-white/10 active:scale-95"
          >
            <ArrowLeft className="h-5 w-5" />
          </button>
          <div>
            <h1 className="font-sans text-xl font-bold tracking-tight text-white md:text-2xl">
              {title}
            </h1>
            <p className="text-xs text-zinc-400">Stream Replay</p>
          </div>
        </header>

        {loadingReplay ? (
          <div className="flex justify-center py-28">
            <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
          </div>
        ) : videoUrl ? (
          <div className="space-y-4">
            <div className="relative aspect-video w-full overflow-hidden rounded-3xl border border-white/10 bg-black shadow-2xl">
              <video
                src={playbackVideoUrl(videoUrl)}
                poster={posterUrl ? cloudinaryUrl(posterUrl, "c_fill,w_1200,h_675") : undefined}
                controls
                autoPlay
                playsInline
                className="h-full w-full object-contain"
              />
            </div>

            <div className="rounded-2xl border border-white/10 bg-[#161622] p-4 flex items-center justify-between">
              <div className="flex items-center gap-3">
                {host?.avatarUrl || hostProfile?.avatarUrl ? (
                  <img
                    src={cloudinaryUrl(host?.avatarUrl || hostProfile?.avatarUrl, "c_fill,w_80,h_80,g_face")}
                    alt=""
                    className="h-10 w-10 rounded-full border border-white/10 object-cover"
                  />
                ) : (
                  <div className="flex h-10 w-10 items-center justify-center rounded-full brand-gradient text-xs font-bold text-white">
                    {(hostHandle || "H").charAt(0).toUpperCase()}
                  </div>
                )}
                <div>
                  <p className="font-sans text-sm font-bold text-white">
                    {hostHandle ? handleLabel(hostHandle) : "Host"}
                  </p>
                </div>
              </div>

              {streamData?.caption && (
                <p className="text-xs text-zinc-400 max-w-xs truncate text-right">
                  {streamData.caption}
                </p>
              )}
            </div>
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center rounded-3xl border border-white/10 bg-[#141420]/70 py-24 text-center">
            <Video className="h-12 w-12 text-zinc-600 mb-3" />
            <p className="font-sans text-base font-bold text-white">Replay not ready</p>
            <p className="mt-1 text-xs text-zinc-400">
              {replayError
                ? (replayError as Error).message
                : "This stream replay is still processing or was not saved."}
            </p>
          </div>
        )}
      </div>
    </AuthGuard>
  );
}
