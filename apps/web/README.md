# XLive Web

Mobile-parity Next.js web app for XLive. Connects to the same Flowfly auth, Easypanel bridge REST API, Socket.IO, Cloudinary media, and Agora live/calls as the Flutter app.

## Setup

```bash
cd apps/web
cp .env.example .env.local
npm install
npm run dev
```

Open http://localhost:3000

## Environment

| Variable | Description |
|----------|-------------|
| `NEXT_PUBLIC_AUTH_BASE_URL` | Flowfly auth (`https://creative.flowfly.dev/dev`) |
| `NEXT_PUBLIC_API_BASE_URL` | Bridge REST + Socket.IO |
| `NEXT_PUBLIC_WS_URL` | Socket.IO origin (same as API base) |
| `NEXT_PUBLIC_CLOUDINARY_CLOUD` | Cloudinary cloud name |

## Auth flow

1. `POST {AUTH}/auth/login` with identifier + password (10 chars)
2. `POST {API}/api/x-live/auth/token` with identity fields
3. Store JWT in localStorage; send `Authorization: Bearer <jwt>` on API calls
4. Socket.IO connects with `auth: { token }`

## Routes

| Path | Mobile equivalent |
|------|-------------------|
| `/` | Splash → home or onboarding |
| `/onboarding` | First launch |
| `/auth/sign-in`, `/auth/create-account`, `/auth/forgot-password` | Auth |
| `/home` | Home tabs (For You / Following / Live / Clips) |
| `/explore` | Explore + search |
| `/live`, `/live/setup`, `/live/[streamId]`, `/live/[streamId]/summary` | Live hub & streaming |
| `/live/replays`, `/live/replay/[id]` | Replays |
| `/create`, `/create/editor` | Post / clip + ffmpeg trim |
| `/media/[id]` | Fullscreen media |
| `/chats`, `/chats/[chatId]`, `/chats/[chatId]/call` | DM + calls |
| `/groups/[groupId]`, `/groups/[groupId]/call`, `/groups/join` | Groups |
| `/profile/me`, `/profile/[userId]`, `/profile/me/edit` | Profiles |
| `/profile/settings/*` | Settings |
| `/profile/creator/*` | Creator tools |
| `/wallet` | Wallet |
| `/marketplace` | Clip resale marketplace |
| `/notifications` | Activity inbox |
| `/hashtags`, `/hashtags/[tag]` | Hashtag discovery |
| `/legal/report` | Report content/users |

## REST API (prefix `/api/x-live`)

See `src/lib/api/` for typed clients mirroring mobile repositories:

- `auth.ts` — Flowfly + bridge token
- `feed.ts` — feeds, search, profiles, follow
- `streams.ts` — live streams, Agora tokens, replays
- `chats.ts` — DM, groups, calls
- `misc.ts` — wallet, gifts, clips, creator, settings, notifications

## Socket.IO events

**Listen:** `xlive_connected`, `user_presence_changed`, `stream_viewers`, `viewer_count_updated`, `stream_ended`, `stream_chat_message`, `gift_sent`, `stream_gift_received`, `stream_transcript`, `message_received`, `message_edited`, `message_deleted`, `unread_updated`, `group_message_received`, `dm_call_incoming`, `dm_call_ended`, `group_call_started`, `group_call_ended`

**Emit:** `send_message`, `group_chat_message`, `stream_chat_message`, `gift_sent`, `join_stream`, `leave_stream`, `end_stream`, `dm_call_start/accept/decline/end`, `group_call_start/join/leave/end`

## Agora

- Live viewer/host: token from `GET /api/x-live/streams/{id}/token?role=host|audience`
- DM/group calls: channel from call session APIs
- Web SDK: `agora-rtc-sdk-ng`

## Stack

Next.js 14 App Router, TypeScript, Tailwind, TanStack Query, Zustand, Socket.IO, Agora Web SDK, React Hook Form + Zod, ffmpeg.wasm editor
