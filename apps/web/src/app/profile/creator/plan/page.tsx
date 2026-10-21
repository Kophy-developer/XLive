"use client";

import { useState, useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { getCreatorSettings, updateCreatorSettings, CreatorSettingsData } from "@/lib/api/creator";

export default function PrivateLivestreamSettingsPage() {
  const { data, refetch } = useQuery<CreatorSettingsData>({
    queryKey: ["creator-settings"],
    queryFn: getCreatorSettings,
  });

  const [pricePerMinute, setPricePerMinute] = useState("0");
  const [allowTalkBack, setAllowTalkBack] = useState(false);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (data) {
      setPricePerMinute(String(data.privateStreamPricePerMinute ?? 0));
      setAllowTalkBack(Boolean(data.allowViewerTalkBack));
    }
  }, [data]);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    setSuccess(false);

    try {
      const priceNum = Math.max(0, parseInt(pricePerMinute, 10) || 0);
      await updateCreatorSettings({
        privateStreamPricePerMinute: priceNum,
        allowViewerTalkBack: allowTalkBack,
      });
      setSuccess(true);
      refetch();
      setTimeout(() => setSuccess(false), 2500);
    } catch (err) {
      setError((err as Error).message || "Failed to save settings");
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthGuard>
      <PageHeader title="Private Livestream" backHref="/profile/creator" />

      <div className="mx-auto max-w-md px-4 py-6 pb-24">
        <form
          onSubmit={handleSave}
          className="rounded-3xl border border-white/10 bg-[#141420]/80 p-6 backdrop-blur-xl shadow-xl space-y-6"
        >
          <p className="text-xs text-zinc-400">
            These settings apply to private livestreams only. Public streams are unaffected.
          </p>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Price per minute (0 = Free)
            </label>
            <Input
              type="number"
              min={0}
              placeholder="0"
              value={pricePerMinute}
              onChange={(e) => setPricePerMinute(e.target.value)}
              className="h-11 font-semibold"
            />
          </div>

          <div className="space-y-2 pt-1">
            <p className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Allow viewer talk-back
            </p>
            <label className="flex items-start gap-3 cursor-pointer">
              <input
                type="checkbox"
                checked={allowTalkBack}
                onChange={(e) => setAllowTalkBack(e.target.checked)}
                className="mt-1 h-5 w-5 rounded-md accent-brand-purple cursor-pointer"
              />
              <span className="text-xs font-semibold uppercase text-zinc-400 leading-relaxed">
                When enabled, you can grant private stream viewers permission to speak on air
              </span>
            </label>
          </div>

          {error ? (
            <div className="rounded-2xl bg-red-500/10 p-3 text-xs font-semibold text-red-400">
              {error}
            </div>
          ) : null}

          {success ? (
            <div className="rounded-2xl bg-emerald-500/10 p-3 text-xs font-semibold text-emerald-400">
              Settings saved successfully!
            </div>
          ) : null}

          <Button
            type="submit"
            disabled={loading}
            className="h-12 w-full rounded-2xl brand-gradient font-display text-sm font-bold text-white shadow-lg shadow-brand-purple/25 transition hover:opacity-95 disabled:opacity-50"
          >
            {loading ? "Saving…" : "Save"}
          </Button>
        </form>
      </div>
    </AuthGuard>
  );
}
