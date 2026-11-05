"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { AuthGuard } from "@/components/auth-guard";
import { searchUsers } from "@/lib/api/feed";
import {
  createStream,
  getUserFollowers,
  getUserFollowing,
  sendStreamInvite,
  startStream,
} from "@/lib/api/streams";
import { useAuthStore } from "@/lib/stores";
import type { XLiveUser } from "@/lib/types";
import { cloudinaryUrl, cn } from "@/lib/utils";
import {
  AlertCircle,
  ArrowLeft,
  Check,
  Crown,
  Globe,
  Lock,
  Radio,
  Search,
  Sparkles,
  Users,
  Video,
} from "lucide-react";

export default function GoLiveSetupPage() {
  const router = useRouter();
  const currentUser = useAuthStore((s) => s.user);

  const [title, setTitle] = useState("My live stream");
  const [caption, setCaption] = useState("");
  const [visibility, setVisibility] = useState<"public" | "private">("public");
  const [chatPolicy, setChatPolicy] = useState("everyone");
  const [joinPolicy, setJoinPolicy] = useState("everyone");

  const [inviteTab, setInviteTab] = useState<"followers" | "following" | "search">("followers");
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedUsers, setSelectedUsers] = useState<Map<string, XLiveUser>>(new Map());

  const [inviteAsCohosts, setInviteAsCohosts] = useState(false);
  const [cohostSplitPercent, setCohostSplitPercent] = useState(20);
  const [captionsEnabled, setCaptionsEnabled] = useState(false);
  const [saveEnabled, setSaveEnabled] = useState(true);

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const userId = currentUser?.id ?? "";

  const { data: followersData, isLoading: loadingFollowers } = useQuery({
    queryKey: ["followers", userId],
    queryFn: () => getUserFollowers(userId),
    enabled: Boolean(userId && inviteTab === "followers"),
  });

  const { data: followingData, isLoading: loadingFollowing } = useQuery({
    queryKey: ["following", userId],
    queryFn: () => getUserFollowing(userId),
    enabled: Boolean(userId && inviteTab === "following"),
  });

  const [searchResults, setSearchResults] = useState<XLiveUser[]>([]);
  const [searching, setSearching] = useState(false);

  useEffect(() => {
    if (inviteTab !== "search") return;
    const q = searchQuery.trim();
    if (!q) {
      setSearchResults([]);
      return;
    }
    const timer = setTimeout(async () => {
      setSearching(true);
      try {
        const res = await searchUsers(q);
        const filtered = (res.users || []).filter((u) => u.id !== userId);
        setSearchResults(filtered);
      } catch {
        setSearchResults([]);
      } finally {
        setSearching(false);
      }
    }, 280);
    return () => clearTimeout(timer);
  }, [searchQuery, inviteTab, userId]);

  const displayedUsers: XLiveUser[] =
    inviteTab === "followers"
      ? followersData?.users || []
      : inviteTab === "following"
      ? followingData?.users || []
      : searchResults;

  const maxCohosts = 3;
  const maxTotalSplit = 90;
  const selectedCount = selectedUsers.size;
  const totalCohostSplit = inviteAsCohosts ? Math.min(maxTotalSplit, selectedCount * cohostSplitPercent) : 0;
  const hostKeepPercent = Math.max(10, 100 - totalCohostSplit);

  function toggleUserSelection(user: XLiveUser) {
    setSelectedUsers((prev) => {
      const next = new Map(prev);
      if (next.has(user.id)) {
        next.delete(user.id);
      } else {
        if (inviteAsCohosts && next.size >= maxCohosts) {
          setError(`You can invite at most ${maxCohosts} co-hosts (up to 4 hosts total).`);
          return prev;
        }
        next.set(user.id, user);
      }
      setError("");
      return next;
    });
  }

  async function handleGoLive(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) {
      setError("Please enter a stream title");
      return;
    }

    if (inviteAsCohosts && selectedUsers.size > maxCohosts) {
      setError(`Maximum ${maxCohosts} co-hosts allowed.`);
      return;
    }

    setError("");
    setLoading(true);

    try {
      const isPriv = visibility === "private";
      const stream = await createStream({
        title: title.trim(),
        caption: caption.trim(),
        visibility,
        isPrivate: isPriv,
        chatPolicy: isPriv ? "everyone" : chatPolicy,
        joinPolicy: isPriv ? "subscribers" : joinPolicy,
        captionsEnabled,
        saveEnabled,
        durationMinutes: 60,
        inviteUserIds: Array.from(selectedUsers.keys()),
      });

      const inviteAsCohost = visibility === "private" && inviteAsCohosts;
      const invitePromises = Array.from(selectedUsers.values()).map((person) =>
        sendStreamInvite(stream.id, person.id, {
          role: inviteAsCohost ? "cohost" : "viewer",
          earningsSplitPercent: inviteAsCohost ? cohostSplitPercent : undefined,
        }).catch(() => null)
      );
      await Promise.all(invitePromises);

      await startStream(stream.id);
      router.push(`/live/${stream.id}`);
    } catch (err) {
      setError((err as Error).message || "Failed to start live stream");
      setLoading(false);
    }
  }

  return (
    <AuthGuard>
      <div className="mx-auto max-w-xl px-4 py-6 pb-24 md:px-6">
        <header className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => router.push("/live")}
              className="flex h-10 w-10 items-center justify-center rounded-2xl border border-white/10 bg-white/5 text-white transition hover:bg-white/10 active:scale-95"
            >
              <ArrowLeft className="h-5 w-5" />
            </button>
            <div>
              <h1 className="font-sans text-2xl font-bold tracking-tight text-white">
                Start a live stream
              </h1>
              <p className="text-xs text-zinc-400">
                Go on air and share with your followers in real time.
              </p>
            </div>
          </div>
          <div className="flex h-10 w-10 items-center justify-center rounded-2xl brand-gradient text-white shadow-lg shadow-brand-purple/20">
            <Radio className="h-5 w-5 animate-pulse" />
          </div>
        </header>

        <form
          onSubmit={handleGoLive}
          className="space-y-6 rounded-[28px] border border-white/10 bg-[#161622]/95 p-5 shadow-2xl backdrop-blur-2xl md:p-7"
        >
          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Title
            </label>
            <input
              type="text"
              placeholder="Stream title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              required
              className="h-12 w-full rounded-2xl border border-white/10 bg-[#1e1e2d] px-4 font-sans text-sm font-semibold text-white placeholder-zinc-500 outline-none transition focus:border-brand-purple focus:ring-2 focus:ring-brand-purple/20"
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Caption (Optional)
            </label>
            <textarea
              placeholder="#live #xlive"
              value={caption}
              onChange={(e) => setCaption(e.target.value)}
              rows={2}
              className="w-full resize-none rounded-2xl border border-white/10 bg-[#1e1e2d] p-4 font-sans text-sm text-white placeholder-zinc-500 outline-none transition focus:border-brand-purple focus:ring-2 focus:ring-brand-purple/20"
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Visibility
            </label>
            <div className="grid grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setVisibility("public")}
                className={cn(
                  "flex items-center justify-center gap-2.5 rounded-2xl border p-3.5 font-sans text-xs font-bold transition active:scale-98",
                  visibility === "public"
                    ? "border-brand-purple bg-brand-purple/20 text-white shadow-lg shadow-brand-purple/15"
                    : "border-white/10 bg-[#1e1e2d] text-zinc-400 hover:text-white hover:bg-white/5"
                )}
              >
                <Globe className="h-4 w-4 text-emerald-400" />
                <span>Public</span>
              </button>
              <button
                type="button"
                onClick={() => setVisibility("private")}
                className={cn(
                  "flex items-center justify-center gap-2.5 rounded-2xl border p-3.5 font-sans text-xs font-bold transition active:scale-98",
                  visibility === "private"
                    ? "border-amber-400/80 bg-amber-500/20 text-white shadow-lg shadow-amber-500/15"
                    : "border-white/10 bg-[#1e1e2d] text-zinc-400 hover:text-white hover:bg-white/5"
                )}
              >
                <Lock className="h-4 w-4 text-amber-400" />
                <span>Private</span>
              </button>
            </div>
          </div>

          {visibility === "public" ? (
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-1.5">
                <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
                  Who Can Chat
                </label>
                <select
                  value={chatPolicy}
                  onChange={(e) => setChatPolicy(e.target.value)}
                  className="h-12 w-full cursor-pointer rounded-2xl border border-white/10 bg-[#1e1e2d] px-4 font-sans text-xs font-semibold text-white outline-none transition focus:border-brand-purple"
                >
                  <option value="everyone" className="bg-[#1e1e2d] text-white">Everyone</option>
                  <option value="followers" className="bg-[#1e1e2d] text-white">Followers</option>
                </select>
              </div>

              <div className="space-y-1.5">
                <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
                  Who Can Join
                </label>
                <select
                  value={joinPolicy}
                  onChange={(e) => setJoinPolicy(e.target.value)}
                  className="h-12 w-full cursor-pointer rounded-2xl border border-white/10 bg-[#1e1e2d] px-4 font-sans text-xs font-semibold text-white outline-none transition focus:border-brand-purple"
                >
                  <option value="everyone" className="bg-[#1e1e2d] text-white">Everyone</option>
                  <option value="followers" className="bg-[#1e1e2d] text-white">Followers</option>
                  <option value="subscribers" className="bg-[#1e1e2d] text-white">Subscribers</option>
                </select>
              </div>
            </div>
          ) : (
            <div className="flex items-center gap-3.5 rounded-2xl border border-amber-500/30 bg-amber-500/10 p-4">
              <Crown className="h-6 w-6 shrink-0 text-amber-400" />
              <div>
                <p className="font-sans text-xs font-bold text-white">
                  Subscribers only
                </p>
                <p className="mt-0.5 text-[11px] leading-relaxed text-zinc-400">
                  Private live streams are exclusively accessible to your active channel subscribers. Other viewers cannot join.
                </p>
              </div>
            </div>
          )}

          <div className="space-y-3 rounded-2xl border border-white/10 bg-[#1a1a28] p-4">
            <div className="flex items-center justify-between">
              <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-300">
                Invite People (Optional)
              </label>
              {selectedUsers.size > 0 && (
                <span className="rounded-full bg-brand-purple/20 px-2.5 py-0.5 text-[11px] font-bold text-brand-purple">
                  {selectedUsers.size} selected
                </span>
              )}
            </div>

            <div className="flex items-center gap-2 rounded-xl bg-black/30 p-1">
              <button
                type="button"
                onClick={() => setInviteTab("followers")}
                className={cn(
                  "flex-1 rounded-lg py-1.5 text-center font-sans text-xs font-bold transition",
                  inviteTab === "followers"
                    ? "bg-white/15 text-white"
                    : "text-zinc-400 hover:text-white"
                )}
              >
                Followers
              </button>
              <button
                type="button"
                onClick={() => setInviteTab("following")}
                className={cn(
                  "flex-1 rounded-lg py-1.5 text-center font-sans text-xs font-bold transition",
                  inviteTab === "following"
                    ? "bg-white/15 text-white"
                    : "text-zinc-400 hover:text-white"
                )}
              >
                Following
              </button>
              <button
                type="button"
                onClick={() => setInviteTab("search")}
                className={cn(
                  "flex-1 rounded-lg py-1.5 text-center font-sans text-xs font-bold transition",
                  inviteTab === "search"
                    ? "brand-gradient text-white shadow-sm"
                    : "text-zinc-400 hover:text-white"
                )}
              >
                Search
              </button>
            </div>

            {inviteTab === "search" && (
              <div className="relative">
                <Search className="absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-zinc-400" />
                <input
                  type="text"
                  placeholder="Search by name or username (e.g. john)"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="h-10 w-full rounded-xl border border-white/10 bg-[#12121e] pl-9 pr-4 font-sans text-xs text-white placeholder-zinc-500 outline-none transition focus:border-brand-purple"
                />
              </div>
            )}

            <div className="max-h-56 space-y-2 overflow-y-auto pr-1">
              {inviteTab === "search" && searching ? (
                <div className="py-6 text-center text-xs text-zinc-500">Searching creators…</div>
              ) : (inviteTab === "followers" && loadingFollowers) || (inviteTab === "following" && loadingFollowing) ? (
                <div className="py-6 text-center text-xs text-zinc-500">Loading list…</div>
              ) : displayedUsers.length === 0 ? (
                <div className="py-6 text-center text-xs text-zinc-500">
                  {inviteTab === "search"
                    ? searchQuery
                      ? "No creators found"
                      : "Type a name to search people to invite"
                    : "No users in this list"}
                </div>
              ) : (
                displayedUsers.map((u) => {
                  const isSelected = selectedUsers.has(u.id);
                  const name = u.username ? `@${u.username}` : "@user";
                  return (
                    <button
                      key={u.id}
                      type="button"
                      onClick={() => toggleUserSelection(u)}
                      className={cn(
                        "flex w-full items-center justify-between rounded-xl border p-2.5 text-left transition active:scale-99",
                        isSelected
                          ? "border-brand-purple/60 bg-brand-purple/15 text-white"
                          : "border-white/5 bg-[#12121e]/80 text-zinc-300 hover:bg-white/5"
                      )}
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        {u.avatarUrl ? (
                          <img
                            src={cloudinaryUrl(u.avatarUrl, "c_fill,w_80,h_80,g_face")}
                            alt=""
                            className="h-9 w-9 rounded-full border border-white/10 object-cover"
                          />
                        ) : (
                          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-white/10 font-sans text-xs font-bold text-white">
                            {name.charAt(0).toUpperCase()}
                          </div>
                        )}
                        <div className="min-w-0">
                          <p className="truncate font-sans text-xs font-bold text-white">
                            {name}
                          </p>
                          <p className="truncate text-[10px] text-zinc-400">
                            @{u.username}
                          </p>
                        </div>
                      </div>

                      <div
                        className={cn(
                          "flex h-5 w-5 shrink-0 items-center justify-center rounded-lg border transition",
                          isSelected
                            ? "border-brand-purple bg-brand-purple text-white shadow-sm"
                            : "border-white/20 bg-transparent"
                        )}
                      >
                        {isSelected && <Check className="h-3.5 w-3.5 stroke-[3]" />}
                      </div>
                    </button>
                  );
                })
              )}
            </div>
          </div>

          <div className="space-y-4 rounded-2xl border border-white/10 bg-[#1a1a28] p-4">
            {visibility === "private" ? (
            <>
            <label className="flex items-start justify-between gap-3 cursor-pointer">
              <div>
                <p className="font-sans text-xs font-bold uppercase tracking-wider text-white flex items-center gap-1.5">
                  <Users className="h-4 w-4 text-brand-purple" />
                  Invite Selected People as Co-Hosts
                </p>
                <p className="mt-1 text-[11px] leading-relaxed text-zinc-400">
                  Co-hosts join with live split-screen video and audio (up to 4 hosts total).
                </p>
              </div>
              <input
                type="checkbox"
                checked={inviteAsCohosts}
                onChange={(e) => {
                  const checked = e.target.checked;
                  setInviteAsCohosts(checked);
                  if (checked && selectedUsers.size > maxCohosts) {
                    const keep = Array.from(selectedUsers.entries()).slice(0, maxCohosts);
                    setSelectedUsers(new Map(keep));
                  }
                }}
                className="mt-1 h-5 w-5 rounded-md accent-brand-purple cursor-pointer"
              />
            </label>

            {inviteAsCohosts && (
              <div className="rounded-xl border border-white/10 bg-[#12121e] p-3.5 space-y-2.5 animate-in fade-in duration-200">
                <div className="flex items-center justify-between font-sans text-xs">
                  <span className="font-bold text-white">
                    Each co-host receives: <span className="text-brand-purple font-extrabold">{cohostSplitPercent}%</span>
                  </span>
                  <span className="text-zinc-400 text-[11px]">
                    Host keeps: <span className="text-emerald-400 font-bold">~{hostKeepPercent}%</span>
                  </span>
                </div>
                <input
                  type="range"
                  min={5}
                  max={50}
                  step={5}
                  value={cohostSplitPercent}
                  onChange={(e) => setCohostSplitPercent(Number(e.target.value))}
                  className="w-full accent-brand-purple cursor-pointer"
                />
                <p className="text-[10px] text-zinc-500">
                  Sharing formula applies automatically to stream gifts and earnings earned during the broadcast.
                </p>
              </div>
            )}
            </>
            ) : null}

            <div className="border-t border-white/5 pt-3">
              <label className="flex items-start justify-between gap-3 cursor-pointer">
                <div>
                  <p className="font-sans text-xs font-bold uppercase tracking-wider text-white flex items-center gap-1.5">
                    <Sparkles className="h-4 w-4 text-sky-400" />
                    Enable Live AI Translator
                  </p>
                  <p className="mt-1 text-[11px] leading-relaxed text-zinc-400">
                    Live captions for you and every viewer. Viewers get the translated line when the server sends it.
                  </p>
                </div>
                <input
                  type="checkbox"
                  checked={captionsEnabled}
                  onChange={(e) => setCaptionsEnabled(e.target.checked)}
                  className="mt-1 h-5 w-5 rounded-md accent-brand-purple cursor-pointer"
                />
              </label>
            </div>

            <div className="border-t border-white/5 pt-3">
              <label className="flex items-start justify-between gap-3 cursor-pointer">
                <div>
                  <p className="font-sans text-xs font-bold uppercase tracking-wider text-white flex items-center gap-1.5">
                    <Video className="h-4 w-4 text-emerald-400" />
                    Save Stream after it Ends (Video replay + transcript)
                  </p>
                  <p className="mt-1 text-[11px] leading-relaxed text-zinc-400">
                    Full video replay is archived to your channel and visible on the replay page.
                  </p>
                </div>
                <input
                  type="checkbox"
                  checked={saveEnabled}
                  onChange={(e) => setSaveEnabled(e.target.checked)}
                  className="mt-1 h-5 w-5 rounded-md accent-brand-purple cursor-pointer"
                />
              </label>
            </div>
          </div>

          {error && (
            <div className="flex items-center gap-2.5 rounded-2xl bg-red-500/10 p-3.5 font-sans text-xs font-semibold text-red-400">
              <AlertCircle className="h-4 w-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <div className="flex items-center gap-3 pt-2">
            <button
              type="button"
              onClick={() => router.push("/live")}
              className="h-12 flex-1 rounded-2xl border border-white/10 bg-white/5 font-sans text-xs font-bold text-zinc-300 transition hover:bg-white/10 hover:text-white active:scale-98"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading || !title.trim()}
              className="h-12 flex-1 rounded-2xl brand-gradient font-sans text-xs font-bold text-white shadow-xl shadow-brand-purple/25 transition hover:opacity-95 active:scale-98 disabled:opacity-40"
            >
              {loading ? (
                <span className="flex items-center justify-center gap-2">
                  <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                  Starting live…
                </span>
              ) : selectedUsers.size === 0 ? (
                "+ Go Live"
              ) : visibility === "private" && inviteAsCohosts ? (
                "+ Go Live · Invite co-host"
              ) : visibility === "private" ? (
                "+ Go Live · Invite guest"
              ) : (
                "+ Go Live · Invite"
              )}
            </button>
          </div>
        </form>
      </div>
    </AuthGuard>
  );
}
