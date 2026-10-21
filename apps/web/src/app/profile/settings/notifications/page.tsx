"use client";

import { useState } from "react";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { useAuthStore } from "@/lib/stores";
import { updateMe } from "@/lib/api/auth";
import { Volume2, PhoneCall, Radio } from "lucide-react";

export default function NotificationsSettingsPage() {
  const user = useAuthStore((s) => s.user);
  const setUser = useAuthStore((s) => s.setUser);

  const [settings, setSettings] = useState({
    notifyFriendsLive: user?.settings?.notifyFriendsLive ?? true,
    inAppSound: user?.settings?.inAppSound ?? true,
    notifyIncomingCalls: user?.settings?.notifyIncomingCalls ?? true,
  });
  const [saving, setSaving] = useState(false);

  async function handleToggle(key: keyof typeof settings) {
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

  return (
    <AuthGuard>
      <PageHeader title="Notifications" backHref="/profile/settings" />

      <div className="mx-auto max-w-md px-4 py-6 pb-24 space-y-4">
        <div className="rounded-3xl border border-white/10 bg-[#141420]/80 p-5 backdrop-blur-xl divide-y divide-white/10 shadow-xl">
          <div className="flex items-center justify-between py-3.5 first:pt-1 last:pb-1">
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-white/5 text-brand-purple">
                <Radio className="h-4 w-4" />
              </div>
              <div>
                <p className="text-xs font-bold text-white">Live Broadcast Alerts</p>
                <p className="text-[11px] text-zinc-400">Notify when creators you follow go live</p>
              </div>
            </div>
            <input
              type="checkbox"
              checked={settings.notifyFriendsLive}
              onChange={() => handleToggle("notifyFriendsLive")}
              disabled={saving}
              className="h-5 w-5 rounded-md accent-brand-purple cursor-pointer"
            />
          </div>

          <div className="flex items-center justify-between py-3.5">
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-white/5 text-brand-purple">
                <Volume2 className="h-4 w-4" />
              </div>
              <div>
                <p className="text-xs font-bold text-white">In-App Sounds</p>
                <p className="text-[11px] text-zinc-400">Play sounds for messages and gift notifications</p>
              </div>
            </div>
            <input
              type="checkbox"
              checked={settings.inAppSound}
              onChange={() => handleToggle("inAppSound")}
              disabled={saving}
              className="h-5 w-5 rounded-md accent-brand-purple cursor-pointer"
            />
          </div>

          <div className="flex items-center justify-between py-3.5">
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-white/5 text-brand-purple">
                <PhoneCall className="h-4 w-4" />
              </div>
              <div>
                <p className="text-xs font-bold text-white">Call Notifications</p>
                <p className="text-[11px] text-zinc-400">Ringtone and alerts for direct audio/video calls</p>
              </div>
            </div>
            <input
              type="checkbox"
              checked={settings.notifyIncomingCalls}
              onChange={() => handleToggle("notifyIncomingCalls")}
              disabled={saving}
              className="h-5 w-5 rounded-md accent-brand-purple cursor-pointer"
            />
          </div>
        </div>
      </div>
    </AuthGuard>
  );
}
