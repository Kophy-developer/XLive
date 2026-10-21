"use client";

import { useState } from "react";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { useAuthStore } from "@/lib/stores";
import { updateMe } from "@/lib/api/auth";
import { creatorToolsEnabled, setCreatorMode } from "@/lib/creator-mode";
import { Eye, Globe, Shield, Sparkles } from "lucide-react";

export default function PreferencesSettingsPage() {
  const user = useAuthStore((s) => s.user);
  const setUser = useAuthStore((s) => s.setUser);

  const [creatorMode, setCreatorModeState] = useState(() => creatorToolsEnabled(user));
  const [settings, setSettings] = useState({
    discoverable: user?.settings?.discoverable ?? true,
    showAdultContent: user?.settings?.showAdultContent ?? false,
    postVisibilityDefault: user?.settings?.postVisibilityDefault ?? "everyone",
  });
  const [saving, setSaving] = useState(false);

  async function handleToggle(key: "discoverable" | "showAdultContent") {
    const next = { ...settings, [key]: !settings[key] };
    setSettings(next);
    setSaving(true);
    try {
      const updated = await updateMe({
        settings: {
          ...(user?.settings ?? {}),
          ...next,
        },
      });
      setUser(updated);
    } catch {
      setSettings(settings);
    } finally {
      setSaving(false);
    }
  }

  async function handleVisibilityChange(val: string) {
    const next = { ...settings, postVisibilityDefault: val };
    setSettings(next);
    setSaving(true);
    try {
      const updated = await updateMe({
        settings: {
          ...(user?.settings ?? {}),
          postVisibilityDefault: val,
        },
      });
      setUser(updated);
    } catch {
      setSettings(settings);
    } finally {
      setSaving(false);
    }
  }

  return (
    <AuthGuard>
      <PageHeader title="General" backHref="/profile/settings" />

      <div className="mx-auto max-w-md px-4 py-6 pb-24 space-y-4">
        <div className="rounded-3xl border border-white/10 bg-[#141420]/80 p-5 backdrop-blur-xl divide-y divide-white/10 shadow-xl">
          <div className="flex items-center justify-between py-3.5 first:pt-1 last:pb-1">
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-white/5 text-brand-purple">
                <Sparkles className="h-4 w-4" />
              </div>
              <div>
                <p className="text-xs font-bold text-white">Creator mode</p>
                <p className="text-[11px] text-zinc-400">Show Creator Tools on your profile</p>
              </div>
            </div>
            <input
              type="checkbox"
              checked={creatorMode}
              onChange={() => {
                const next = !creatorMode;
                setCreatorModeState(next);
                setCreatorMode(next);
              }}
              className="h-5 w-5 rounded-md accent-brand-purple cursor-pointer"
            />
          </div>

          <div className="flex items-center justify-between py-3.5 first:pt-1 last:pb-1">
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-white/5 text-brand-purple">
                <Globe className="h-4 w-4" />
              </div>
              <div>
                <p className="text-xs font-bold text-white">Profile Discoverability</p>
                <p className="text-[11px] text-zinc-400">Suggest your profile in Explore & search</p>
              </div>
            </div>
            <input
              type="checkbox"
              checked={settings.discoverable}
              onChange={() => handleToggle("discoverable")}
              disabled={saving}
              className="h-5 w-5 rounded-md accent-brand-purple cursor-pointer"
            />
          </div>

          <div className="flex items-center justify-between py-3.5">
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-white/5 text-brand-purple">
                <Shield className="h-4 w-4" />
              </div>
              <div>
                <p className="text-xs font-bold text-white">Adult Content Filter</p>
                <p className="text-[11px] text-zinc-400">Allow 18+ sensitive media in your feeds</p>
              </div>
            </div>
            <input
              type="checkbox"
              checked={settings.showAdultContent}
              onChange={() => handleToggle("showAdultContent")}
              disabled={saving}
              className="h-5 w-5 rounded-md accent-brand-purple cursor-pointer"
            />
          </div>

          <div className="py-3.5 space-y-2">
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-white/5 text-brand-purple">
                <Eye className="h-4 w-4" />
              </div>
              <div>
                <p className="text-xs font-bold text-white">Default Post Visibility</p>
                <p className="text-[11px] text-zinc-400">Who can see your posts by default</p>
              </div>
            </div>
            <select
              value={settings.postVisibilityDefault}
              onChange={(e) => handleVisibilityChange(e.target.value)}
              className="w-full h-10 rounded-2xl border border-white/10 bg-[#161622] px-3 text-xs font-semibold text-white capitalize focus:outline-none focus:ring-1 focus:ring-brand-purple"
            >
              <option value="everyone">Everyone</option>
              <option value="followers">Followers Only</option>
              <option value="subscribers">Subscribers Only</option>
            </select>
          </div>
        </div>
      </div>
    </AuthGuard>
  );
}
