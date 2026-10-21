"use client";

import { useState } from "react";
import { Flag, Loader2, X } from "lucide-react";
import { sendProfileReport } from "@/lib/report/formsubmit";
import { handleLabel } from "@/lib/utils";

export function ReportProfileDialog({
  open,
  onClose,
  reportedUserId,
  reportedHandle,
  reportedName,
  reporterId,
  reporterHandle,
}: {
  open: boolean;
  onClose: () => void;
  reportedUserId: string;
  reportedHandle?: string;
  reportedName?: string;
  reporterId?: string;
  reporterHandle?: string;
}) {
  const [reason, setReason] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const [sent, setSent] = useState(false);
  const handle = handleLabel(reportedHandle || reportedName || "user");
  const ready = reason.trim().length >= 8 && !sending;

  if (!open) return null;

  async function submit() {
    if (!ready) return;
    setSending(true);
    setError("");
    try {
      await sendProfileReport({
        reportedUserId,
        reportedHandle: handle,
        reportedName,
        reason,
        reporterId,
        reporterHandle,
      });
      setSent(true);
    } catch (err) {
      setError((err as Error).message || "Could not send report.");
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="fixed inset-0 z-[120] flex items-center justify-center bg-black/70 p-4 backdrop-blur-md">
      <div className="w-full max-w-lg overflow-hidden rounded-3xl border border-white/10 bg-[#14141c] shadow-2xl shadow-black/50">
        <div className="flex items-start justify-between border-b border-white/10 px-6 py-5">
          <div className="flex items-center gap-3">
            <span className="flex h-10 w-10 items-center justify-center rounded-2xl bg-brand-purple/20 text-brand-purple">
              <Flag className="h-4 w-4" />
            </span>
            <div>
              <h2 className="text-base font-bold text-white">Report {handle}</h2>
              <p className="mt-0.5 text-xs text-zinc-400">Tell us what this account did. We’ll review it.</p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="flex h-8 w-8 items-center justify-center rounded-full bg-white/5 text-zinc-400 hover:bg-white/10 hover:text-white"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
        {sent ? (
          <div className="px-6 py-10 text-center">
            <p className="text-sm font-semibold text-white">Report sent</p>
            <p className="mt-2 text-sm text-zinc-400">Thanks. Our team will look into {handle}.</p>
            <button
              type="button"
              onClick={onClose}
              className="mt-6 rounded-full brand-gradient px-6 py-2.5 text-xs font-bold text-white"
            >
              Done
            </button>
          </div>
        ) : (
          <div className="px-6 py-5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-500">Why are you reporting this account?</label>
            <textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              rows={8}
              placeholder="Describe what happened…"
              className="mt-2 w-full resize-none rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-3 text-sm leading-relaxed text-white outline-none placeholder:text-zinc-600 focus:border-brand-purple/50"
            />
            {error ? <p className="mt-2 text-xs text-red-400">{error}</p> : null}
            <div className="mt-5 flex justify-end gap-2">
              <button
                type="button"
                onClick={onClose}
                className="rounded-full border border-white/10 px-4 py-2 text-xs font-semibold text-zinc-300 hover:bg-white/5"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={!ready}
                onClick={submit}
                className="flex items-center gap-2 rounded-full brand-gradient px-5 py-2 text-xs font-bold text-white disabled:opacity-40"
              >
                {sending ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : null}
                Send report
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
