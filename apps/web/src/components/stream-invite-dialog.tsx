"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { acceptStreamInvite, declineStreamInvite, getMyInvites } from "@/lib/api/streams";
import { onSocketEvent, socketEvents } from "@/lib/socket";
import { useAuthStore } from "@/lib/stores";
import type { StreamInvite } from "@/lib/types";
import { cloudinaryUrl } from "@/lib/utils";
import { Check, Radio, Sparkles, Users, X } from "lucide-react";

export function StreamInviteDialog() {
  const router = useRouter();
  const currentUser = useAuthStore((s) => s.user);
  const [invite, setInvite] = useState<StreamInvite | null>(null);
  const [busy, setBusy] = useState(false);
  const handledIdsRef = useRef<Set<string>>(new Set());

  function playAlertChime() {
    try {
      const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sine";
      osc.frequency.setValueAtTime(587.33, ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(880, ctx.currentTime + 0.15);
      gain.gain.setValueAtTime(0.18, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.4);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + 0.4);
    } catch {}
  }

  useEffect(() => {
    if (!currentUser?.id) return;

    let isMounted = true;

    async function checkInvites() {
      try {
        const res = await getMyInvites(1, 10);
        if (!isMounted) return;
        const pending = res.invites.find(
          (i) =>
            i.status === "pending" &&
            !handledIdsRef.current.has(i.id) &&
            (i.streamStatus === "live" || i.streamStatus === "scheduled")
        );
        if (pending && !invite) {
          setInvite(pending);
          playAlertChime();
        }
      } catch {}
    }

    checkInvites();
    const interval = setInterval(checkInvites, 18000);

    const offIncoming = onSocketEvent<Record<string, unknown>>(
      socketEvents.streamInviteIncoming,
      (data) => {
        if (!isMounted) return;
        const id = String(data?.inviteId || data?.id || data?._id || "");
        if (!id || handledIdsRef.current.has(id)) return;

        const streamDoc = (data?.stream && typeof data.stream === "object" ? data.stream : {}) as Record<string, unknown>;
        const hostDoc = (data?.host && typeof data.host === "object" ? data.host : data?.actor && typeof data.actor === "object" ? data.actor : {}) as Record<string, unknown>;

        const newInvite: StreamInvite = {
          id,
          streamId: String(data?.streamId || streamDoc._id || streamDoc.id || ""),
          hostId: String(data?.hostId || hostDoc.id || hostDoc._id || ""),
          inviteeId: String(data?.inviteeId || currentUser.id),
          role: String(data?.role || "viewer"),
          earningsSplitPercent: typeof data?.earningsSplitPercent === "number" ? data.earningsSplitPercent : Number(data?.earningsSplitPercent) || undefined,
          status: "pending",
          streamTitle: String(data?.streamTitle || streamDoc.title || "Live stream"),
          streamStatus: "live",
          hostName: String(data?.hostName || hostDoc.displayName || hostDoc.username || "A creator"),
          hostAvatarUrl: (data?.hostAvatarUrl || hostDoc.avatarUrl) ? String(data?.hostAvatarUrl || hostDoc.avatarUrl) : undefined,
        };

        setInvite(newInvite);
        playAlertChime();
      }
    );

    return () => {
      isMounted = false;
      clearInterval(interval);
      offIncoming();
    };
  }, [currentUser?.id, invite]);

  if (!invite) return null;

  const isCohost = invite.role === "cohost";

  async function handleAccept() {
    if (!invite || busy) return;
    setBusy(true);
    handledIdsRef.current.add(invite.id);
    try {
      await acceptStreamInvite(invite.id);
      const targetStreamId = invite.streamId;
      setInvite(null);
      router.push(`/live/${targetStreamId}?role=${isCohost ? "cohost" : "audience"}`);
    } catch {
      setInvite(null);
    } finally {
      setBusy(false);
    }
  }

  async function handleDecline() {
    if (!invite || busy) return;
    setBusy(true);
    handledIdsRef.current.add(invite.id);
    try {
      await declineStreamInvite(invite.id);
      setInvite(null);
    } catch {
      setInvite(null);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md p-4 animate-in fade-in duration-200">
      <div className="relative w-full max-w-sm rounded-[32px] border border-white/15 bg-[#141420]/95 p-6 shadow-2xl backdrop-blur-2xl text-center animate-in zoom-in-95 duration-200">
        <button
          type="button"
          onClick={handleDecline}
          disabled={busy}
          className="absolute right-4 top-4 flex h-8 w-8 items-center justify-center rounded-full bg-white/5 text-zinc-400 hover:bg-white/10 hover:text-white transition"
        >
          <X className="h-4 w-4" />
        </button>

        <div className="relative mx-auto flex h-20 w-20 items-center justify-center">
          <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-brand-purple/40 opacity-75" />
          <div className="relative flex h-20 w-20 overflow-hidden rounded-full border-2 border-brand-purple/80 bg-surface-hover shadow-xl">
            {invite.hostAvatarUrl ? (
              <img
                src={cloudinaryUrl(invite.hostAvatarUrl, "c_fill,w_160,h_160,g_face")}
                alt=""
                className="h-full w-full object-cover"
              />
            ) : (
              <div className="flex h-full w-full items-center justify-center brand-gradient text-xl font-bold text-white">
                {invite.hostName.charAt(0).toUpperCase()}
              </div>
            )}
          </div>
          <div className="absolute -bottom-1 -right-1 flex h-7 w-7 items-center justify-center rounded-full border-2 border-[#141420] brand-gradient text-white shadow-md">
            {isCohost ? <Users className="h-3.5 w-3.5" /> : <Radio className="h-3.5 w-3.5 animate-pulse" />}
          </div>
        </div>

        <div className="mt-4 inline-flex items-center gap-1.5 rounded-full border border-brand-purple/40 bg-brand-purple/15 px-3 py-1 text-[11px] font-bold text-brand-purple">
          <Sparkles className="h-3 w-3" />
          <span>{isCohost ? "CO-HOST INVITATION" : "STREAM INVITATION"}</span>
        </div>

        <h3 className="mt-2.5 font-sans text-lg font-bold text-white tracking-tight">
          {invite.hostName}
        </h3>
        <p className="mt-1 text-xs text-zinc-400 leading-relaxed px-2">
          invited you to join <span className="font-semibold text-white">“{invite.streamTitle}”</span> {isCohost ? "as a co-host!" : "live broadcast."}
        </p>

        {isCohost && typeof invite.earningsSplitPercent === "number" && (
          <div className="mt-4 rounded-2xl border border-emerald-500/30 bg-emerald-500/10 p-3 text-center">
            <p className="font-sans text-xs font-bold text-emerald-400">
              Co-host Earnings Split: {invite.earningsSplitPercent}%
            </p>
            <p className="mt-0.5 text-[10px] text-zinc-400">
              You will automatically earn {invite.earningsSplitPercent}% of gifts and tips received during the stream.
            </p>
          </div>
        )}

        <div className="mt-6 flex items-center gap-3">
          <button
            type="button"
            onClick={handleDecline}
            disabled={busy}
            className="flex-1 rounded-2xl border border-white/10 bg-white/5 py-3 font-sans text-xs font-bold text-zinc-300 transition hover:bg-white/10 hover:text-white active:scale-98 disabled:opacity-50"
          >
            Decline
          </button>
          <button
            type="button"
            onClick={handleAccept}
            disabled={busy}
            className="flex-1 rounded-2xl brand-gradient py-3 font-sans text-xs font-bold text-white shadow-xl shadow-brand-purple/25 transition hover:opacity-95 active:scale-98 disabled:opacity-50"
          >
            {busy ? (
              <span className="flex items-center justify-center gap-1.5">
                <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-white border-t-transparent" />
                Joining…
              </span>
            ) : (
              <span className="flex items-center justify-center gap-1.5">
                <Check className="h-4 w-4 stroke-[2.5]" />
                Accept & Join
              </span>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
