"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { Input, Textarea } from "@/components/ui/input";
import { AvatarUpload } from "@/components/media-upload";
import { updateMe, uploadAvatar } from "@/lib/api/auth";
import { useAuthStore } from "@/lib/stores";
import { cloudinaryUrl } from "@/lib/utils";

export default function EditProfilePage() {
  const router = useRouter();
  const user = useAuthStore((s) => s.user);
  const setUser = useAuthStore((s) => s.setUser);

  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [form, setForm] = useState({
    displayName: user?.displayName ?? "",
    username: user?.username ?? "",
    bio: user?.bio ?? "",
    email: user?.email ?? "",
    phone: user?.phone ?? "",
    dob: user?.dob ?? "",
    gender: user?.gender ?? "male",
  });

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    setSuccess(false);

    try {
      let updatedAvatarUrl = user?.avatarUrl;
      if (avatarFile) {
        const avatarRes = await uploadAvatar(avatarFile);
        if (avatarRes?.avatarUrl) {
          updatedAvatarUrl = avatarRes.avatarUrl;
        }
      }

      const payload: Record<string, unknown> = {
        displayName: form.displayName.trim(),
        username: form.username.trim(),
        gender: form.gender,
      };

      if (form.bio.trim()) payload.bio = form.bio.trim();
      if (form.email.trim()) payload.email = form.email.trim();
      if (form.phone.trim()) payload.phone = form.phone.trim();
      if (form.dob.trim()) payload.dob = form.dob.trim();
      if (updatedAvatarUrl) payload.avatarUrl = updatedAvatarUrl;

      const updated = await updateMe(payload);
      setUser({ ...user, ...updated, ...(updatedAvatarUrl ? { avatarUrl: updatedAvatarUrl } : {}) });
      setSuccess(true);
      setTimeout(() => {
        router.push("/profile/me");
      }, 700);
    } catch (err) {
      setError((err as Error).message || "Update failed");
    } finally {
      setLoading(false);
    }
  }

  const currentAvatar = user?.avatarUrl
    ? cloudinaryUrl(user.avatarUrl, "c_fill,w_180,h_180,g_face")
    : null;

  return (
    <AuthGuard>
      <PageHeader title="Personal info" backHref="/profile/settings" />

      <div className="mx-auto max-w-md px-4 py-6 pb-24">
        <form onSubmit={handleSave} className="space-y-5 rounded-3xl border border-white/10 bg-[#141420]/80 p-6 backdrop-blur-xl shadow-xl">
          <AvatarUpload
            currentAvatarUrl={currentAvatar}
            onFileSelect={(file) => setAvatarFile(file)}
          />

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Display Name
            </label>
            <Input
              placeholder="e.g. Lekan Alake"
              value={form.displayName}
              onChange={(e) => setForm((f) => ({ ...f, displayName: e.target.value }))}
              required
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Username
            </label>
            <Input
              placeholder="e.g. lalake"
              value={form.username}
              onChange={(e) => setForm((f) => ({ ...f, username: e.target.value }))}
              required
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Bio
            </label>
            <Textarea
              placeholder="Write a brief bio about yourself…"
              value={form.bio}
              onChange={(e) => setForm((f) => ({ ...f, bio: e.target.value }))}
              className="min-h-20"
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Email
            </label>
            <Input
              type="email"
              placeholder="name@example.com"
              value={form.email}
              onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Phone
            </label>
            <Input
              type="tel"
              placeholder="Phone number"
              value={form.phone}
              onChange={(e) => setForm((f) => ({ ...f, phone: e.target.value }))}
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Date of Birth
            </label>
            <Input
              type="date"
              value={form.dob}
              onChange={(e) => setForm((f) => ({ ...f, dob: e.target.value }))}
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Gender
            </label>
            <select
              value={form.gender}
              onChange={(e) => setForm((f) => ({ ...f, gender: e.target.value }))}
              className="flex h-11 w-full rounded-2xl border border-white/10 bg-[#161622] px-4 text-sm font-medium text-white transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-purple/50 focus-visible:border-brand-purple capitalize"
            >
              <option value="male">Male</option>
              <option value="female">Female</option>
              <option value="other">Other</option>
              <option value="prefer_not_to_say">Prefer not to say</option>
            </select>
          </div>

          {error ? (
            <div className="rounded-2xl bg-red-500/10 p-3.5 text-xs font-semibold text-red-400">
              {error}
            </div>
          ) : null}

          {success ? (
            <div className="rounded-2xl bg-emerald-500/10 p-3.5 text-xs font-semibold text-emerald-400">
              Profile updated successfully! Redirecting…
            </div>
          ) : null}

          <Button
            type="submit"
            disabled={loading}
            className="h-12 w-full rounded-2xl brand-gradient font-display text-sm font-bold text-white shadow-lg shadow-brand-purple/25 transition hover:opacity-95 disabled:opacity-50"
          >
            {loading ? (
              <span className="flex items-center gap-2">
                <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                Saving changes…
              </span>
            ) : (
              "Save changes"
            )}
          </Button>
        </form>
      </div>
    </AuthGuard>
  );
}
