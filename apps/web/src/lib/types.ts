export type XLiveUser = {
  id: string;
  username: string;
  email?: string;
  phone?: string;
  firstName?: string;
  lastName?: string;
  displayName?: string;
  bio?: string;
  avatarUrl?: string;
  isCreator?: boolean;
  followerCount?: number;
  followingCount?: number;
  isFollowing?: boolean;
  dob?: string;
  gender?: string;
  language?: string;
  status?: string;
  activityStatus?: string;
  settings?: {
    notifyFriendsLive?: boolean;
    inAppSound?: boolean;
    inAppVibration?: boolean;
    notifyIncomingCalls?: boolean;
    discoverable?: boolean;
    showAdultContent?: boolean;
    appTheme?: string;
    postVisibilityDefault?: string;
    passcodeEnabled?: boolean;
    contentFilters?: string[];
  };
};

export type FeedItem = {
  id: string;
  type: "video" | "clip" | "live" | "post";
  mediaType?: "video" | "image";
  title?: string;
  caption?: string;
  thumbnailUrl?: string;
  previewUrl?: string;
  mediaUrl?: string;
  streamUrl?: string;
  creator?: XLiveUser;
  creatorId?: string;
  creatorName?: string;
  creatorAvatarUrl?: string;
  likeCount?: number;
  commentCount?: number;
  viewCount?: number;
  price?: number;
  isLive?: boolean;
  streamId?: string;
  createdAt?: string;
  accessAllowed?: boolean;
  needsPurchase?: boolean;
  isOwner?: boolean;
  likedByMe?: boolean;
  isFollowing?: boolean;
  albumSlides?: FeedItem[];
};

export type MediaComment = {
  id: string;
  content: string;
  authorId?: string;
  authorName?: string;
  authorAvatarUrl?: string;
  createdAt?: string;
  parentId?: string;
};

export type ChatThread = {
  id: string;
  peer?: XLiveUser;
  lastMessage?: string;
  lastMessageAt?: string;
  unreadCount?: number;
};

export type ChatReplyPreview = {
  id: string;
  senderId?: string;
  senderName?: string;
  content?: string;
  mediaUrl?: string;
  mediaType?: string;
};

export type ChatMessage = {
  id: string;
  chatId: string;
  senderId: string;
  senderName?: string;
  senderAvatar?: string;
  content: string;
  mediaUrl?: string;
  mediaType?: string;
  createdAt: string;
  editedAt?: string;
  replyToMessageId?: string;
  replyTo?: ChatReplyPreview;
  reactions?: { emoji: string; userId?: string; count?: number; userIds?: string[] }[];
  fileName?: string;
};

export type LiveStream = {
  id: string;
  title: string;
  caption?: string;
  hostId: string;
  host?: XLiveUser;
  thumbnailUrl?: string;
  replayUrl?: string;
  viewerCount?: number;
  isLive: boolean;
  startedAt?: string;
  createdAt?: string;
  hasReplay?: boolean;
  captionsEnabled?: boolean;
  captionsAvailable?: boolean;
  saveEnabled?: boolean;
  visibility?: string;
  joinPolicy?: string;
  chatPolicy?: string;
  isPrivate?: boolean;
  pricePerMinute?: number;
  isPaid?: boolean;
};

export type StreamInvite = {
  id: string;
  streamId: string;
  hostId: string;
  inviteeId: string;
  role: string;
  earningsSplitPercent?: number;
  status: string;
  streamTitle: string;
  streamStatus?: string;
  hostName: string;
  hostAvatarUrl?: string;
};

export type GroupSummary = {
  id: string;
  name: string;
  avatarUrl?: string;
  memberCount?: number;
  lastMessage?: string;
  unreadCount?: number;
  members?: { id: string; username?: string; avatarUrl?: string }[];
};

export type WalletInfo = {
  balance: number;
  currency: string;
};

export type GiftCatalogItem = {
  id: string;
  name: string;
  iconUrl?: string;
  price: number;
};

export type NotificationItem = {
  id: string;
  type: string;
  title: string;
  body?: string;
  read?: boolean;
  readAt?: string | null;
  actor?: {
    id: string;
    username?: string;
    displayName?: string;
    avatarUrl?: string;
  } | null;
  data?: Record<string, unknown>;
  createdAt: string;
  targetUrl?: string;
};
