"use client";

import { useInfiniteQuery, useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { FeedGrid } from "@/components/feed-card";
import { ReportProfileDialog } from "@/components/report-profile-dialog";
import { getUserContent, getUserProfile, getUserPresence, followUser, unfollowUser } from "@/lib/api/feed";
import { getMe, signOut } from "@/lib/api/auth";
import { getUserFollowers, getUserFollowing, getUserGifts } from "@/lib/api/creator";
import { enrichGiftRows, parseGiftRows } from "@/lib/gifts";
import { useAuthStore } from "@/lib/stores";
import { cloudinaryUrl } from "@/lib/utils";
import { creatorToolsEnabled } from "@/lib/creator-mode";
import {
  Plus,
  Gift,
  Users,
  ShoppingBag,
} from "lucide-react";

type ProfileTab = "posts" | "overview" | "followers" | "following" | "gifts" | "shop";
type ContentFilter = "all" | "videos" | "clips" | "photos";

const PEOPLE_PAGE_SIZE = 10;

function PeopleRow({ person }: { person: Record<string, unknown> }) {
  const id = person.id || person._id;
  const username = String(person.username || "user");
  const avatarUrl = person.avatarUrl ? String(person.avatarUrl) : "";
  return (
    <div className="flex items-center justify-between p-3">
      <div className="flex min-w-0 items-center gap-3">
        <div className="h-10 w-10 shrink-0 overflow-hidden rounded-full border border-white/10 bg-zinc-800">
          {avatarUrl ? (
            <img
              src={cloudinaryUrl(avatarUrl, "c_fill,w_80,h_80,g_face")}
              alt=""
              className="h-full w-full object-cover"
            />
          ) : (
            <div className="flex h-full w-full items-center justify-center font-bold text-white text-sm brand-gradient">
              {username[0].toUpperCase()}
            </div>
          )}
        </div>
        <p className="truncate text-xs font-bold text-white">@{username}</p>
      </div>
      <Link
        href={`/profile/${id}`}
        className="shrink-0 rounded-full border border-white/15 bg-white/5 px-3 py-1 text-xs font-semibold text-white transition hover:bg-white/10"
      >
        View
      </Link>
    </div>
  );
}

function PeoplePanel({
  people,
  total,
  hasMore,
  loadingMore,
  onLoadMore,
  emptyTitle,
  emptyDescription,
  emptyExtra,
}: {
  people: Record<string, unknown>[];
  total: number;
  hasMore: boolean;
  loadingMore: boolean;
  onLoadMore: () => void;
  emptyTitle: string;
  emptyDescription: string;
  emptyExtra?: React.ReactNode;
}) {
  if (people.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center rounded-3xl border border-white/10 bg-[#141420]/40 py-16 text-center">
        <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-white/5 text-zinc-400">
          <Users className="h-7 w-7" />
        </div>
        <p className="mt-3 font-display text-sm font-bold text-white">{emptyTitle}</p>
        <p className="mt-1 text-xs text-zinc-400">{emptyDescription}</p>
        {emptyExtra}
      </div>
    );
  }

  return (
    <div className="rounded-3xl border border-white/10 bg-[#141420]/70">
      <div className="max-h-[420px] divide-y divide-white/10 overflow-y-auto p-2">
        {people.map((person, i) => (
          <PeopleRow key={String(person.id || person._id || i)} person={person} />
        ))}
      </div>
      {total > people.length || hasMore ? (
        <div className="flex items-center justify-between gap-3 border-t border-white/10 px-4 py-2.5">
          <p className="text-[11px] font-medium tabular-nums text-zinc-400">
            {people.length} of {total}
          </p>
          {hasMore ? (
            <button
              type="button"
              onClick={onLoadMore}
              disabled={loadingMore}
              className="rounded-full border border-white/15 bg-white/5 px-3 py-1 text-xs font-semibold text-white transition hover:bg-white/10 disabled:opacity-50"
            >
              {loadingMore ? "Loading…" : people.length <= PEOPLE_PAGE_SIZE ? "See all" : "Load more"}
            </button>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

export default function ProfilePage() {
  const router = useRouter();
  const params = useParams();
  const userId = (params.userId as string) ?? "me";
  const me = useAuthStore((s) => s.user);
  const setUser = useAuthStore((s) => s.setUser);
  const setAuthenticated = useAuthStore((s) => s.setAuthenticated);

  const isMe = userId === "me" || userId === me?.id;
  const targetId = isMe ? me?.id : userId;

  const [activeTab, setActiveTab] = useState<ProfileTab>("posts");
  const [contentFilter, setContentFilter] = useState<ContentFilter>("all");
  const [followingState, setFollowingState] = useState(false);
  const [followBusy, setFollowBusy] = useState(false);
  const [followError, setFollowError] = useState("");
  const [reportOpen, setReportOpen] = useState(false);

  const { data: profile, refetch: refetchProfile } = useQuery({
    queryKey: ["profile", targetId, isMe],
    queryFn: () => (isMe ? getMe() : getUserProfile(targetId!)),
    enabled: Boolean(targetId) || isMe,
  });

  const followersQuery = useInfiniteQuery({
    queryKey: ["user-followers", targetId],
    queryFn: ({ pageParam }) =>
      targetId
        ? getUserFollowers(targetId, pageParam, PEOPLE_PAGE_SIZE)
        : { docs: [] as Record<string, unknown>[], totalDocs: 0 },
    initialPageParam: 1,
    getNextPageParam: (lastPage, allPages) => {
      const loaded = allPages.reduce((n, page) => n + page.docs.length, 0);
      if (lastPage.docs.length === 0) return undefined;
      if (loaded >= lastPage.totalDocs) return undefined;
      return allPages.length + 1;
    },
    enabled: Boolean(targetId),
  });

  const followingQuery = useInfiniteQuery({
    queryKey: ["user-following", targetId],
    queryFn: ({ pageParam }) =>
      targetId
        ? getUserFollowing(targetId, pageParam, PEOPLE_PAGE_SIZE)
        : { docs: [] as Record<string, unknown>[], totalDocs: 0 },
    initialPageParam: 1,
    getNextPageParam: (lastPage, allPages) => {
      const loaded = allPages.reduce((n, page) => n + page.docs.length, 0);
      if (lastPage.docs.length === 0) return undefined;
      if (loaded >= lastPage.totalDocs) return undefined;
      return allPages.length + 1;
    },
    enabled: Boolean(targetId),
  });

  const { data: giftsData } = useQuery({
    queryKey: ["user-gifts", targetId],
    queryFn: async () => {
      const raw = await getUserGifts(1, 50);
      const rows = await enrichGiftRows(parseGiftRows({ data: { docs: raw.docs, totalDocs: raw.totalDocs } }));
      return { docs: rows, totalDocs: raw.totalDocs || rows.length };
    },
    enabled: isMe,
  });

  const { data: content } = useQuery({
    queryKey: ["user-content", targetId],
    queryFn: () => getUserContent(targetId!),
    enabled: Boolean(targetId),
  });

  const { data: presence } = useQuery({
    queryKey: ["user-presence", targetId, isMe],
    queryFn: () => (isMe ? { online: true, label: "Active now" } : getUserPresence(targetId!)),
    enabled: Boolean(targetId) || isMe,
    refetchInterval: isMe ? false : 30_000,
  });

  useEffect(() => {
    if (isMe) return;
    if (profile && typeof profile.isFollowing === "boolean") {
      setFollowingState(profile.isFollowing);
    }
  }, [isMe, profile, targetId]);

  async function handleSignOut() {
    await signOut();
    setUser(null);
    setAuthenticated(false);
    router.push("/auth/sign-in");
  }

  async function toggleFollow() {
    if (!targetId || followBusy) return;
    const next = !followingState;
    setFollowBusy(true);
    setFollowError("");
    setFollowingState(next);
    try {
      if (next) await followUser(targetId);
      else await unfollowUser(targetId);
      await refetchProfile();
      void followersQuery.refetch();
      void followingQuery.refetch();
    } catch (e) {
      setFollowingState(!next);
      setFollowError(e instanceof Error ? e.message : "Could not update follow");
    } finally {
      setFollowBusy(false);
    }
  }

  const user = profile ?? me;
  const followerDocs = followersQuery.data?.pages.flatMap((page) => page.docs) ?? [];
  const followingDocs = followingQuery.data?.pages.flatMap((page) => page.docs) ?? [];
  const followerCount =
    followersQuery.data?.pages[0]?.totalDocs ?? user?.followerCount ?? 0;
  const followingCount =
    followingQuery.data?.pages[0]?.totalDocs ?? user?.followingCount ?? 0;
  const giftsCount = giftsData?.totalDocs ?? giftsData?.docs?.length ?? 0;
  const giftRows = giftsData?.docs ?? [];

  const rawItems = content?.items ?? [];
  const filteredItems = rawItems.filter((item) => {
    if (contentFilter === "videos") {
      return item.mediaType === "video" && item.type !== "clip";
    }
    if (contentFilter === "clips") {
      return item.type === "clip";
    }
    if (contentFilter === "photos") {
      return item.mediaType === "image";
    }
    return true;
  });

  const tabs: { id: ProfileTab; label: string }[] = [
    { id: "posts", label: "Posts" },
    { id: "overview", label: "Overview" },
    { id: "followers", label: "Followers" },
    { id: "following", label: "Following" },
    { id: "gifts", label: "Gifts" },
    { id: "shop", label: "Shop" },
  ];

  return (
    <AuthGuard>
      <PageHeader
        title={isMe ? "Profile" : `@${user?.username ?? "user"}`}
        backHref="/home"
        action={
          isMe ? (
            <button
              type="button"
              onClick={handleSignOut}
              className="rounded-full border border-red-500/40 px-3.5 py-1 text-xs font-semibold text-red-400 transition hover:bg-red-500/10"
            >
              Log out
            </button>
          ) : (
            <div className="flex flex-col items-end gap-1">
              <div className="flex items-center gap-2">
                <Button
                  size="sm"
                  disabled={followBusy}
                  onClick={toggleFollow}
                  className={
                    followingState
                      ? "rounded-full border border-white/20 bg-white/5 text-xs font-semibold text-white disabled:opacity-60"
                      : "rounded-full brand-gradient text-xs font-semibold text-white shadow-md shadow-brand-purple/20 disabled:opacity-60"
                  }
                >
                  {followBusy ? "…" : followingState ? "Following" : "Follow"}
                </Button>
                <button
                  type="button"
                  onClick={() => setReportOpen(true)}
                  className="rounded-full border border-white/15 bg-white/5 px-3.5 py-1.5 text-xs font-semibold text-zinc-200 transition hover:border-white/30 hover:bg-white/10"
                >
                  Report
                </button>
              </div>
              {followError ? <p className="max-w-[220px] text-right text-[10px] font-medium text-red-400">{followError}</p> : null}
            </div>
          )
        }
      />

      <div className="mx-auto max-w-6xl px-4 pb-28 pt-4 sm:px-6">
        <div className="mx-auto max-w-2xl">
        <div className="flex flex-col items-center text-center">
          <div className="relative mb-3">
            {user?.avatarUrl ? (
              <img
                src={cloudinaryUrl(user.avatarUrl, "c_fill,w_180,h_180,g_face")}
                alt=""
                className="h-24 w-24 rounded-full object-cover ring-2 ring-brand-purple/40 shadow-xl"
              />
            ) : (
              <div className="flex h-24 w-24 items-center justify-center rounded-full brand-gradient font-display text-3xl font-black text-white shadow-xl shadow-brand-purple/20">
                {user?.username?.[0]?.toUpperCase() ?? "U"}
              </div>
            )}
            {presence?.online ? (
              <span className="absolute bottom-1 right-1 h-4 w-4 rounded-full border-2 border-[#0c0c12] bg-emerald-500 shadow-sm" />
            ) : null}
          </div>

          <h1 className="font-display text-xl font-bold text-white">
            @{user?.username || "user"}
          </h1>

          <div className="mt-5 grid w-full max-w-xs grid-cols-3 gap-6 border-y border-white/10 py-3 text-center">
            <button
              type="button"
              onClick={() => setActiveTab("followers")}
              className="group transition"
            >
              <div className="font-sans text-lg font-bold tracking-tight text-white tabular-nums group-hover:text-brand-purple">
                {followerCount}
              </div>
              <div className="text-[11px] font-medium uppercase tracking-wider text-zinc-400">
                Followers
              </div>
            </button>
            <button
              type="button"
              onClick={() => setActiveTab("following")}
              className="group transition"
            >
              <div className="font-sans text-lg font-bold tracking-tight text-white tabular-nums group-hover:text-brand-purple">
                {followingCount}
              </div>
              <div className="text-[11px] font-medium uppercase tracking-wider text-zinc-400">
                Following
              </div>
            </button>
            <button
              type="button"
              onClick={() => setActiveTab("gifts")}
              className="group transition"
            >
              <div className="font-sans text-lg font-bold tracking-tight text-white tabular-nums group-hover:text-brand-purple">
                {giftsCount}
              </div>
              <div className="text-[11px] font-medium uppercase tracking-wider text-zinc-400">
                Gifts
              </div>
            </button>
          </div>

          {isMe ? (
            <div className="mt-4 flex flex-wrap items-center justify-center gap-2">
              <Link
                href="/create"
                className="flex items-center gap-1.5 rounded-full brand-gradient px-5 py-2 text-xs font-bold text-white shadow-lg shadow-brand-purple/25 transition hover:opacity-95"
              >
                <Plus className="h-3.5 w-3.5 stroke-[3]" />
                Create
              </Link>
              <Link
                href="/profile/settings"
                className="rounded-full border border-white/15 bg-white/5 px-4 py-2 text-xs font-semibold text-zinc-200 transition hover:border-white/30 hover:bg-white/10"
              >
                Settings
              </Link>
              <Link
                href="/wallet"
                className="rounded-full border border-white/15 bg-white/5 px-4 py-2 text-xs font-semibold text-zinc-200 transition hover:border-white/30 hover:bg-white/10"
              >
                Wallet
              </Link>
              {creatorToolsEnabled(me) ? (
                <Link
                  href="/profile/creator"
                  className="rounded-full border border-white/15 bg-white/5 px-4 py-2 text-xs font-semibold text-zinc-200 transition hover:border-white/30 hover:bg-white/10"
                >
                  Creator Tools
                </Link>
              ) : null}
            </div>
          ) : null}
        </div>

        <div className="mt-6 flex justify-center border-b border-white/10">
          <div className="inline-flex max-w-full overflow-x-auto no-scrollbar text-xs font-semibold">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                type="button"
                onClick={() => setActiveTab(tab.id)}
                className={`whitespace-nowrap border-b-2 px-4 pb-2.5 font-display transition-colors ${
                  activeTab === tab.id
                    ? "border-brand-purple font-bold text-white"
                    : "border-transparent text-zinc-400 hover:text-zinc-200"
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>

        {activeTab === "posts" ? (
          <div className="mt-4 flex justify-center">
            <div className="inline-flex max-w-full items-center gap-1 overflow-x-auto no-scrollbar rounded-full border border-white/10 bg-[#141420]/80 p-1">
              {[
                { id: "all", label: "All" },
                { id: "videos", label: "Videos" },
                { id: "clips", label: "Clips" },
                { id: "photos", label: "Photos" },
              ].map((f) => (
                <button
                  key={f.id}
                  type="button"
                  onClick={() => setContentFilter(f.id as ContentFilter)}
                  className={`whitespace-nowrap rounded-full px-3.5 py-1.5 text-[11px] font-semibold transition ${
                    contentFilter === f.id
                      ? "brand-gradient text-white shadow-md shadow-brand-purple/20"
                      : "text-zinc-400 hover:text-white"
                  }`}
                >
                  {f.label}
                </button>
              ))}
            </div>
          </div>
        ) : null}

        {activeTab === "overview" && (
          <div className="mt-5 space-y-4">
            <div className="divide-y divide-white/10 rounded-3xl border border-white/10 bg-[#141420]/70 p-2 backdrop-blur-xl">
              <div className="flex items-center justify-between px-4 py-3 text-xs">
                <span className="font-medium text-zinc-400">Username</span>
                <span className="font-semibold text-white">@{user?.username || "—"}</span>
              </div>
              <div className="flex items-center justify-between px-4 py-3 text-xs">
                <span className="font-medium text-zinc-400">Display name</span>
                <span className="font-semibold text-white">{user?.displayName || "—"}</span>
              </div>
              {isMe ? (
                <>
                  <div className="flex items-center justify-between px-4 py-3 text-xs">
                    <span className="font-medium text-zinc-400">Email</span>
                    <span className="font-semibold text-white">{user?.email || "—"}</span>
                  </div>
                  <div className="flex items-center justify-between px-4 py-3 text-xs">
                    <span className="font-medium text-zinc-400">Phone</span>
                    <span className="font-semibold text-white">{user?.phone || "—"}</span>
                  </div>
                  <div className="flex items-center justify-between px-4 py-3 text-xs">
                    <span className="font-medium text-zinc-400">Date of birth</span>
                    <span className="font-semibold text-white">{user?.dob || "—"}</span>
                  </div>
                </>
              ) : null}
              <div className="flex items-center justify-between px-4 py-3 text-xs">
                <span className="font-medium text-zinc-400">Gender</span>
                <span className="font-semibold capitalize text-white">
                  {user?.gender || "Male"}
                </span>
              </div>
              <div className="flex items-center justify-between px-4 py-3 text-xs">
                <span className="font-medium text-zinc-400">Language</span>
                <span className="font-semibold text-white uppercase">{user?.language || "en"}</span>
              </div>
              <div className="flex items-center justify-between px-4 py-3 text-xs">
                <span className="font-medium text-zinc-400">Bio</span>
                <span className="max-w-xs truncate text-right font-semibold text-white">
                  {user?.bio || "No bio set"}
                </span>
              </div>
              <div className="flex items-center justify-between px-4 py-3 text-xs">
                <span className="font-medium text-zinc-400">Status</span>
                <span className={`flex items-center gap-1.5 font-semibold capitalize ${presence?.online ? "text-emerald-400" : "text-zinc-300"}`}>
                  {presence?.online ? <span className="h-2 w-2 rounded-full bg-emerald-400" /> : null}
                  {presence?.label || "Offline"}
                </span>
              </div>
            </div>
          </div>
        )}

        {activeTab === "followers" && (
          <div className="mt-5">
            <PeoplePanel
              people={followerDocs}
              total={followerCount}
              hasMore={Boolean(followersQuery.hasNextPage)}
              loadingMore={followersQuery.isFetchingNextPage}
              onLoadMore={() => followersQuery.fetchNextPage()}
              emptyTitle="No followers yet"
              emptyDescription="When fans follow this profile, they will show up here"
            />
          </div>
        )}

        {activeTab === "following" && (
          <div className="mt-5">
            <PeoplePanel
              people={followingDocs}
              total={followingCount}
              hasMore={Boolean(followingQuery.hasNextPage)}
              loadingMore={followingQuery.isFetchingNextPage}
              onLoadMore={() => followingQuery.fetchNextPage()}
              emptyTitle="Not following anyone"
              emptyDescription="Discover top creators and friends to follow in Explore"
              emptyExtra={
                <Link
                  href="/explore"
                  className="mt-4 rounded-full brand-gradient px-4 py-1.5 text-xs font-semibold text-white shadow-md shadow-brand-purple/20"
                >
                  Explore Creators
                </Link>
              }
            />
          </div>
        )}

        {activeTab === "gifts" && (
          <div className="mt-5">
            {!giftRows.length ? (
              <div className="flex flex-col items-center justify-center rounded-3xl border border-white/10 bg-[#141420]/40 py-16 text-center">
                <div className="flex h-14 w-14 items-center justify-center rounded-2xl brand-gradient text-white shadow-lg shadow-brand-purple/20">
                  <Gift className="h-7 w-7" />
                </div>
                <p className="mt-3 font-display text-sm font-bold text-white">No gifts received yet</p>
                <p className="mt-1 max-w-xs text-xs text-zinc-400">
                  Gifts sent by viewers during live broadcasts and clips will appear here
                </p>
              </div>
            ) : (
              <ul className="space-y-2 rounded-3xl border border-white/10 bg-[#141420]/40 p-2">
                {giftRows.map((g) => (
                  <li
                    key={g.id}
                    className="flex items-center gap-3 rounded-2xl px-3 py-2.5 hover:bg-white/5"
                  >
                    {g.iconUrl ? (
                      <img
                        src={cloudinaryUrl(g.iconUrl)}
                        alt=""
                        className="h-10 w-10 rounded-full object-cover"
                      />
                    ) : (
                      <div className="flex h-10 w-10 items-center justify-center rounded-full bg-amber-400/15 text-amber-300">
                        <Gift className="h-4 w-4" />
                      </div>
                    )}
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-bold text-white">
                        {g.senderName} sent {g.giftName}
                      </p>
                      <p className="truncate text-xs text-zinc-400">
                        {g.amountPaid ? `${g.amountPaid} coins` : `×${g.quantity}`}
                      </p>
                    </div>
                    <span className="text-xs font-semibold text-white/80">x{g.quantity}</span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}

        {activeTab === "shop" && (
          <div className="mt-5">
            <div className="flex flex-col items-center justify-center rounded-3xl border border-white/10 bg-[#141420]/40 py-16 text-center">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-white/5 text-zinc-400">
                <ShoppingBag className="h-7 w-7" />
              </div>
              <p className="mt-3 font-display text-sm font-bold text-white">No collectibles in shop</p>
              <p className="mt-1 max-w-xs text-xs text-zinc-400">
                Mint collectible clips from Creator Tools to sell exclusive moments to your fans
              </p>
              {isMe ? (
                <Link
                  href="/create?type=collectible"
                  className="mt-4 rounded-full brand-gradient px-4 py-2 text-xs font-bold text-white shadow-md shadow-brand-purple/20"
                >
                  Mint Collectible Clip
                </Link>
              ) : null}
            </div>
          </div>
        )}

        </div>

        {activeTab === "posts" ? (
          <div className="mt-5">
            <FeedGrid
              items={filteredItems}
              empty={
                contentFilter === "all"
                  ? "No posts or clips published yet"
                  : `No ${contentFilter} found`
              }
              allowOwnerDelete={isMe}
              hideCreator={isMe}
              variant="profile"
            />
          </div>
        ) : null}
      </div>
      {!isMe && reportOpen ? (
        <ReportProfileDialog
          open
          onClose={() => setReportOpen(false)}
          reportedUserId={targetId || userId}
          reportedHandle={user?.username}
          reportedName={user?.displayName}
          reporterId={me?.id}
          reporterHandle={me?.username}
        />
      ) : null}
    </AuthGuard>
  );
}
