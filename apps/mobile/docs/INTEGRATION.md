# XLive mobile — API integration

Single reference for bridge integration status, hosts, and deferred work.

## Hosts

| System | URL |
|--------|-----|
| Auth (Flowfly) | `https://creative.flowfly.dev/dev` |
| Bridge / XLive API | `https://xlive-app-bcqre.ondigitalocean.app` |
| Socket.IO | Same origin as bridge |

## Auth flow

1. Register/login on Flowfly
2. Email verify: `POST /auth/verify-request` + `POST /auth/verify-code` (`type: "email"`)
3. `POST /auth/login`
4. Bridge JWT: `POST /api/x-live/auth/token` with **one** field — `identifier` (email) **or** `username`
5. JWT on all `/api/x-live/*` and socket connect

## Implemented

### Auth & profile
- Register, sign-in, verify, forgot password, bridge token exchange
- `GET/PATCH /users/me`, avatar upload, password/passcode
- `GET/PATCH /settings`, notification status, live-stream notification toggle
- Username read-only on edit profile (API only accepts displayName, bio, language, gender)

### Feed & social
- Feeds: for-you, following, live, clips
- Profile, follow/unfollow, comments, likes, video/clip detail
- `POST /feed/interactions` on preview open (view)
- Block user from other-user profile menu
- Followers / following lists (`/social/followers`, `/social/following`)
- Blocked accounts list + unblock (`/social/blocked`)
- Hashtag discover + feed (`/social/hashtags`, `/social/hashtag-feed`); explore tab trending wired

### Chats & groups
- DMs, groups, discover, join, create, messages, read, unread summary + nav badge
- User search for new DM
- Group members list, leave group, join-with-code screen
- Socket: `message_received`, `group_message_received`, `unread_updated`, join/leave group, send messages

#### DM & group calls (9 socket events)

| Event | Direction | Status | Notes |
|-------|-----------|--------|-------|
| `dm_call_incoming` | listen | ✅ | Global `IncomingCallOverlay` — accept/decline |
| `dm_call_accepted` | listen | ✅ | Caller status → Connected |
| `dm_call_declined` | listen | ✅ | Ends call screen |
| `dm_call_ended` | listen | ✅ | Ends call screen |
| `dm_call_start` / `accept` / `decline` / `end` | emit | ✅ | After REST start/accept/decline/end |
| `group_call_started` | listen | ✅ | Global overlay — Join / Dismiss |
| `group_call_joined` | listen | ✅ | Participant count in `GroupCallScreen` |
| `group_call_left` | listen | ✅ | Participant count |
| `group_call_ended` | listen | ✅ | Pops call screen |
| `group_call_media_state` | listen | ⏳ | Bound; mute/camera via REST for now |
| `group_call_start` / `join` / `leave` / `end` | emit | ✅ | After REST start/join/leave/end |

REST: `POST /chats/:id/calls`, `POST /groups/:id/calls`, accept/decline/end/join/leave + Agora token in response. App bar call buttons on DM + group chat.

### Streams, wallet, gifts
- Create/start/end stream (public + private), list live, watch — **shared TikTok-style live UI** (`LiveDuringScreen`) for both
- Stream invites: followers list, send invite (host overlay), inbox accept/decline/join
- Wallet balance, transactions, payment methods, fund initiate (redirect URL)
- Gift catalog + send during live (REST → server broadcasts `gift_sent`); host gift bursts + gift history sheet
- Public live: chat, gifts, viewer list, remove viewer (host)
- Private live: per-minute billing snackbar, talk-back + mute (host sheet shows talk-back controls only when `visibility: private`)

#### Live stream sockets (10 events)

| Event | Status | Notes |
|-------|--------|-------|
| `join_stream` emit | ✅ | Ack before Agora token; blocks entry on `ok: false` (e.g. insufficient balance) |
| `leave_stream` emit | ✅ | On viewer leave + dispose |
| `end_stream` emit | ✅ | Host end flow (after REST end) |
| `stream_viewers` listen | ✅ | Host popover + manage sheet; updates count from payload |
| `viewer_count` listen | ✅ | Top bar count |
| `remove_viewer` emit | ✅ | Host manage sheet (public + private) |
| `viewer_removed` listen | ✅ | Tear down Agora, pop; handles `billing_failed` reason |
| `stream_ended` listen | ✅ | All participants → summary (host + viewers) |
| `stream_chat_message` both | ✅ | Emit `{ streamId, content }`; listen parses nested `comment` object |
| `gift_sent` both | ✅ | Listen → center burst; send via REST `/gifts/send` |

Private-only (separate from the 10 above): `stream:billingTick`, mute/unmute, talk-back grant/revoke.

### Backend request (private live talk-back)

When a viewer joins a stream and the host has `allowViewerTalkBack: true` in creator settings, the server should **auto-emit** `stream:talkBackGranted` with `{ streamId, userId }` after a successful `join_stream`. The mobile client does not enable viewer mic until that event (or a manual `stream:grantTalkBack`).

### Creator & settings
- Creator earnings + breakdown by range (today/week/month)
- Creator performance analytics screen wired to API
- Withdrawal methods (bank) + withdrawal request
- Content keyword filters: list, add, remove
- Notification settings: live-stream friends toggle only (unsupported toggles removed)

## Bridge auth

Bridge token exchange verified for test user `xlive_1781971529` (`POST /api/x-live/auth/token` → JWT).

## Deferred (no API or client/SDK not integrated)

### Requires native SDK or platform setup
- Stripe/PayPal/Apple/Google in-app payment SDKs (redirect fund flow wired; verify/poll not automated)
- Firebase Cloud Messaging + `POST /notifications/devices`
- Google / Apple OAuth (no endpoints in Postman)
- Agora on simulator (use a real device for cam/mic publish)

### API available; UI not wired
- Clip/video upload & creator clip tools
- Collectible clips, marketplace, subscriptions
- Chat media upload, reactions, edit, delete
- Group roles / admin actions beyond members + leave
- Archived clips, PayPal/crypto withdrawal types
- Pagination / infinite scroll on feeds and messages
- Delete account (no endpoint in collection)
- Report user (no dedicated endpoint; group report exists)

### Local UI only
- Suggested creators on chats hub
- Video player (thumbnail-only preview)
- OAuth buttons on create account
