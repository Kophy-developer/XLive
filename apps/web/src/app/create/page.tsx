"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { Input, Textarea } from "@/components/ui/input";
import { MediaUpload } from "@/components/media-upload";
import { VideoEditor } from "@/components/video-editor";
import { readVideoDurationSeconds, uploadCollectibleClip, uploadVideo } from "@/lib/api/misc";
import { newFeedAlbumId, wrapFeedAlbumCaption } from "@/lib/feed-album";
import { AlertCircle } from "lucide-react";

const VISIBILITY_OPTIONS = [
  { value: "everyone", label: "Everyone" },
  { value: "followers", label: "Followers" },
  { value: "subscribers", label: "Subscribers" },
];

const CATEGORY_OPTIONS = [
  { value: "music", label: "Music" },
  { value: "comedy", label: "Comedy" },
  { value: "education", label: "Education" },
  { value: "gaming", label: "Gaming" },
  { value: "lifestyle", label: "Lifestyle" },
  { value: "sports", label: "Sports" },
  { value: "news", label: "News" },
  { value: "other", label: "Other" },
];

function CreatePageContent() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const searchParams = useSearchParams();
  const initialTab = searchParams.get("type") === "collectible" ? "collectible" : "post";

  const [activeTab, setActiveTab] = useState<"post" | "collectible">(initialTab);
  const [files, setFiles] = useState<File[]>([]);
  const [videoDurations, setVideoDurations] = useState<Record<number, number>>({});
  const [editingIndex, setEditingIndex] = useState<number | null>(null);

  const [caption, setCaption] = useState("");
  const [visibility, setVisibility] = useState("everyone");
  const [category, setCategory] = useState("music");
  const [unlockPrice, setUnlockPrice] = useState("");
  const [confirmCopyright, setConfirmCopyright] = useState(true);

  const [clipName, setClipName] = useState("");
  const [clipPrice, setClipPrice] = useState("5");
  const [clipSupply, setClipSupply] = useState("10");

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const file = files[0] ?? null;
  const isVideo = files.some((item) => item.type.startsWith("video/"));
  const editingFile = editingIndex != null ? files[editingIndex] : null;

  async function handlePublish(e: React.FormEvent) {
    e.preventDefault();
    if (!files.length) {
      setError("Please choose a photo or video to upload");
      return;
    }

    if (activeTab === "post") {
      if (isVideo && !confirmCopyright) {
        setError("Please confirm sound copyright before publishing");
        return;
      }

      setError("");
      setLoading(true);
      let uploaded = 0;
      try {
        const albumId = files.length > 1 ? newFeedAlbumId() : null;
        for (let i = 0; i < files.length; i++) {
          const item = files[i];
          const itemIsVideo = item.type.startsWith("video/");
          let duration = videoDurations[i];
          if (itemIsVideo && !(duration && duration > 0)) {
            duration = await readVideoDurationSeconds(item);
          }
          const itemCaption = albumId
            ? wrapFeedAlbumCaption(caption.trim(), albumId)
            : caption.trim();
          await uploadVideo(item, {
            caption: itemCaption,
            visibility,
            category,
            unlockPrice: unlockPrice.trim() ? unlockPrice.trim() : undefined,
            soundCopyrightChecked: confirmCopyright,
            type: "post",
            duration,
          });
          uploaded += 1;
        }
        await queryClient.invalidateQueries({ queryKey: ["feed"] });
        await queryClient.invalidateQueries({ queryKey: ["explore-feed"] });
        await queryClient.invalidateQueries({ queryKey: ["user-content"] });
        router.push("/home");
      } catch (err) {
        const rest = files.length - uploaded;
        setError(
          uploaded
            ? `Published ${uploaded} of ${files.length}. ${rest} did not upload. ${(err as Error).message || ""}`.trim()
            : (err as Error).message || "Failed to publish post"
        );
      } finally {
        setLoading(false);
      }
    } else {
      if (!file) {
        setError("Please choose a photo or video to upload");
        return;
      }
      if (!clipName.trim()) {
        setError("Please enter a name for your collectible clip");
        return;
      }

      setError("");
      setLoading(true);
      try {
        await uploadCollectibleClip(file, {
          name: clipName.trim(),
          caption: caption.trim(),
          description: caption.trim(),
          price: parseInt(clipPrice, 10) || 5,
          maxSupply: parseInt(clipSupply, 10) || 10,
        });
        await queryClient.invalidateQueries({ queryKey: ["feed"] });
        await queryClient.invalidateQueries({ queryKey: ["explore-feed"] });
        await queryClient.invalidateQueries({ queryKey: ["user-content"] });
        router.push("/profile/me");
      } catch (err) {
        setError((err as Error).message || "Failed to mint collectible clip");
      } finally {
        setLoading(false);
      }
    }
  }

  return (
    <div className="mx-auto max-w-lg px-4 py-6 pb-28">
      <PageHeader title="Create content" backHref="/home" />

      {editingFile && editingIndex != null && editingFile.type.startsWith("video/") ? (
        <VideoEditor
          file={editingFile}
          onCancel={() => setEditingIndex(null)}
          onApply={(next, seconds) => {
            const idx = editingIndex;
            setFiles((prev) => prev.map((item, i) => (i === idx ? next : item)));
            setVideoDurations((prev) => ({ ...prev, [idx]: Math.max(1, Math.round(seconds)) }));
            setEditingIndex(null);
          }}
        />
      ) : null}

      <div className="rounded-3xl border border-white/10 bg-[#141420]/85 p-6 backdrop-blur-xl shadow-2xl space-y-5">
        <div className="grid grid-cols-2 gap-2 rounded-2xl bg-black/40 p-1 border border-white/10">
          <button
            type="button"
            onClick={() => {
              setActiveTab("post");
              setError("");
            }}
            className={`rounded-xl py-2.5 text-xs font-bold transition ${
              activeTab === "post"
                ? "brand-gradient text-white shadow-lg shadow-brand-purple/25"
                : "text-zinc-400 hover:text-white"
            }`}
          >
            Post
          </button>
          <button
            type="button"
            onClick={() => {
              setActiveTab("collectible");
              setError("");
            }}
            className={`rounded-xl py-2.5 text-xs font-bold transition ${
              activeTab === "collectible"
                ? "brand-gradient text-white shadow-lg shadow-brand-purple/25"
                : "text-zinc-400 hover:text-white"
            }`}
          >
            Collectible clip
          </button>
        </div>

        <form onSubmit={handlePublish} className="space-y-4">
          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Media File
            </label>
            <MediaUpload
              files={activeTab === "collectible" ? files.slice(0, 1) : files}
              onFilesChange={(next) => {
                const limited = activeTab === "collectible" ? next.slice(0, 1) : next;
                setFiles(limited);
                setError("");
                setVideoDurations({});
                limited.forEach((item, index) => {
                  if (item.type.startsWith("video/")) {
                    readVideoDurationSeconds(item).then((seconds) => {
                      setVideoDurations((prev) => ({ ...prev, [index]: seconds }));
                    }).catch(() => {});
                  }
                });
              }}
              multiple={activeTab === "post"}
              isCollectible={activeTab === "collectible"}
              onEditVideo={(index) => setEditingIndex(index)}
            />
          </div>

          {activeTab === "collectible" ? (
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
                Clip Name
              </label>
              <Input
                placeholder="e.g. Exclusive Behind The Scenes"
                value={clipName}
                onChange={(e) => setClipName(e.target.value)}
                required
              />
            </div>
          ) : null}

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Caption
            </label>
            <Textarea
              placeholder={
                activeTab === "post"
                  ? "Write a caption, tags, mentions…"
                  : "Describe what makes this collectible clip special…"
              }
              value={caption}
              onChange={(e) => setCaption(e.target.value)}
              className="min-h-24"
            />
          </div>

          {activeTab === "post" ? (
            <>
              <div className="space-y-1.5">
                <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
                  Visibility
                </label>
                <select
                  value={visibility}
                  onChange={(e) => setVisibility(e.target.value)}
                  className="flex h-11 w-full rounded-2xl border border-white/10 bg-[#161622] px-4 text-xs font-semibold text-white transition focus:outline-none focus:ring-2 focus:ring-brand-purple/50 focus:border-brand-purple capitalize"
                >
                  {VISIBILITY_OPTIONS.map((opt) => (
                    <option key={opt.value} value={opt.value} className="bg-[#161622] text-white">
                      {opt.label}
                    </option>
                  ))}
                </select>
              </div>

              <div className="space-y-1.5">
                <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
                  Unlock Price (Required for videos over 5 min)
                </label>
                <Input
                  type="number"
                  min={0}
                  placeholder="e.g. 100 coins"
                  value={unlockPrice}
                  onChange={(e) => setUnlockPrice(e.target.value)}
                />
                <p className="text-[11px] text-zinc-400">
                  Free videos: up to 5 min. Paid unlock: up to 60 min.
                </p>
              </div>

              <div className="space-y-1.5">
                <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
                  Category
                </label>
                <select
                  value={category}
                  onChange={(e) => setCategory(e.target.value)}
                  className="flex h-11 w-full rounded-2xl border border-white/10 bg-[#161622] px-4 text-xs font-semibold text-white transition focus:outline-none focus:ring-2 focus:ring-brand-purple/50 focus:border-brand-purple capitalize"
                >
                  {CATEGORY_OPTIONS.map((opt) => (
                    <option key={opt.value} value={opt.value} className="bg-[#161622] text-white">
                      {opt.label}
                    </option>
                  ))}
                </select>
              </div>

              {isVideo ? (
                <div className="pt-1">
                  <label className="flex items-center gap-3 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={confirmCopyright}
                      onChange={(e) => setConfirmCopyright(e.target.checked)}
                      className="h-5 w-5 rounded-md accent-brand-purple cursor-pointer"
                    />
                    <span className="text-xs font-semibold text-white">
                      I confirm sound copyright
                    </span>
                  </label>
                </div>
              ) : null}
            </>
          ) : (
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
                  Price (Coins)
                </label>
                <Input
                  type="number"
                  min={1}
                  value={clipPrice}
                  onChange={(e) => setClipPrice(e.target.value)}
                  required
                />
              </div>
              <div className="space-y-1.5">
                <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
                  Editions / Supply
                </label>
                <Input
                  type="number"
                  min={1}
                  value={clipSupply}
                  onChange={(e) => setClipSupply(e.target.value)}
                  required
                />
              </div>
            </div>
          )}

          {error ? (
            <div className="flex items-center gap-2 rounded-2xl bg-red-500/10 p-3.5 text-xs font-semibold text-red-400">
              <AlertCircle className="h-4 w-4 shrink-0" />
              <span>{error}</span>
            </div>
          ) : null}

          <div className="flex items-center gap-3 pt-2">
            <button
              type="button"
              onClick={() => router.back()}
              className="h-12 flex-1 rounded-2xl border border-white/10 bg-white/5 font-display text-xs font-bold text-zinc-300 transition hover:bg-white/10 hover:text-white"
            >
              Cancel
            </button>
            <Button
              type="submit"
              disabled={loading || !files.length}
              className="h-12 flex-1 rounded-2xl brand-gradient font-display text-xs font-bold text-white shadow-lg shadow-brand-purple/25 transition hover:opacity-95 disabled:opacity-40"
            >
              {loading ? (
                <span className="flex items-center gap-2">
                  <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                  Publishing…
                </span>
              ) : activeTab === "post" ? (
                "Publish Post"
              ) : (
                "Mint Collectible"
              )}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}

export default function CreatePage() {
  return (
    <AuthGuard>
      <Suspense
        fallback={
          <div className="flex justify-center py-20">
            <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
          </div>
        }
      >
        <CreatePageContent />
      </Suspense>
    </AuthGuard>
  );
}
