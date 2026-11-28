"use client";

import { useState } from "react";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { setUserPasscode, removeUserPasscode } from "@/lib/api/creator";
import { changePassword, passwordRuleError, serverPasswordError } from "@/lib/api/auth";
import { Lock, KeyRound } from "lucide-react";

export default function SecuritySettingsPage() {
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordError, setPasswordError] = useState("");
  const [passwordSuccess, setPasswordSuccess] = useState(false);
  const [serverNewPwError, setServerNewPwError] = useState("");
  const newPwError = serverNewPwError || (newPassword ? passwordRuleError(newPassword) : null);

  const [passcode, setPasscode] = useState("");
  const [passcodeLoading, setPasscodeLoading] = useState(false);
  const [passcodeError, setPasscodeError] = useState("");
  const [passcodeSuccess, setPasscodeSuccess] = useState("");

  async function handlePasswordUpdate(e: React.FormEvent) {
    e.preventDefault();
    if (!currentPassword) {
      setPasswordError("Please enter your current password");
      return;
    }
    if (newPwError) return;
    setPasswordLoading(true);
    setPasswordError("");
    setPasswordSuccess(false);

    try {
      await changePassword({ currentPassword, newPassword });
      setPasswordSuccess(true);
      setCurrentPassword("");
      setNewPassword("");
    } catch (err) {
      const pwServer = serverPasswordError(err);
      if (pwServer) setServerNewPwError(pwServer);
      else setPasswordError((err as Error).message || "Failed to update password");
    } finally {
      setPasswordLoading(false);
    }
  }

  async function handleSetPasscode(e: React.FormEvent) {
    e.preventDefault();
    const clean = passcode.trim();
    if (clean.length < 4 || clean.length > 6) {
      setPasscodeError("Passcode must be between 4 and 6 digits");
      return;
    }
    setPasscodeLoading(true);
    setPasscodeError("");
    setPasscodeSuccess("");

    try {
      await setUserPasscode(clean);
      setPasscodeSuccess("App passcode activated successfully");
      setPasscode("");
    } catch (err) {
      setPasscodeError((err as Error).message || "Failed to set passcode");
    } finally {
      setPasscodeLoading(false);
    }
  }

  async function handleRemovePasscode() {
    setPasscodeLoading(true);
    setPasscodeError("");
    setPasscodeSuccess("");

    try {
      await removeUserPasscode();
      setPasscodeSuccess("App passcode removed");
      setPasscode("");
    } catch (err) {
      setPasscodeError((err as Error).message || "Failed to remove passcode");
    } finally {
      setPasscodeLoading(false);
    }
  }

  return (
    <AuthGuard>
      <PageHeader title="Security" backHref="/profile/settings" />

      <div className="mx-auto max-w-md px-4 py-6 pb-24 space-y-6">
        <form
          onSubmit={handlePasswordUpdate}
          className="rounded-3xl border border-white/10 bg-[#141420]/80 p-6 backdrop-blur-xl shadow-xl space-y-4"
        >
          <div className="flex items-center gap-3 mb-1">
            <div className="flex h-10 w-10 items-center justify-center rounded-2xl brand-gradient text-white shadow-md shadow-brand-purple/20">
              <KeyRound className="h-5 w-5" />
            </div>
            <div>
              <h2 className="font-display text-base font-bold text-white">Change password</h2>
              <p className="text-xs text-zinc-400">Update your account login password</p>
            </div>
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Current password
            </label>
            <Input
              type="password"
              placeholder="••••••••"
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
              required
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              New password
            </label>
            <Input
              type="password"
              placeholder="••••••••"
              value={newPassword}
              onChange={(e) => {
                setNewPassword(e.target.value);
                setServerNewPwError("");
              }}
              required
              aria-invalid={Boolean(newPwError)}
            />
            {newPwError ? <p className="text-xs font-semibold text-red-400">{newPwError}</p> : null}
          </div>

          {passwordError ? (
            <div className="rounded-2xl bg-red-500/10 p-3 text-xs font-semibold text-red-400">
              {passwordError}
            </div>
          ) : null}

          {passwordSuccess ? (
            <div className="rounded-2xl bg-emerald-500/10 p-3 text-xs font-semibold text-emerald-400">
              Password updated successfully!
            </div>
          ) : null}

          <Button
            type="submit"
            disabled={passwordLoading}
            className="h-11 w-full rounded-2xl brand-gradient font-display text-sm font-bold text-white shadow-lg shadow-brand-purple/25 transition hover:opacity-95 disabled:opacity-50"
          >
            {passwordLoading ? "Updating…" : "Update password"}
          </Button>
        </form>

        <form
          onSubmit={handleSetPasscode}
          className="rounded-3xl border border-white/10 bg-[#141420]/80 p-6 backdrop-blur-xl shadow-xl space-y-4"
        >
          <div className="flex items-center gap-3 mb-1">
            <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-white/5 text-zinc-300">
              <Lock className="h-5 w-5 text-brand-purple" />
            </div>
            <div>
              <h2 className="font-display text-base font-bold text-white">App passcode</h2>
              <p className="text-xs text-zinc-400">Protect private chats and broadcasts with a PIN</p>
            </div>
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Passcode (4–6 digits)
            </label>
            <Input
              type="password"
              inputMode="numeric"
              maxLength={6}
              placeholder="e.g. 1234"
              value={passcode}
              onChange={(e) => setPasscode(e.target.value.replace(/\D/g, ""))}
            />
          </div>

          {passcodeError ? (
            <div className="rounded-2xl bg-red-500/10 p-3 text-xs font-semibold text-red-400">
              {passcodeError}
            </div>
          ) : null}

          {passcodeSuccess ? (
            <div className="rounded-2xl bg-emerald-500/10 p-3 text-xs font-semibold text-emerald-400">
              {passcodeSuccess}
            </div>
          ) : null}

          <div className="space-y-2 pt-1">
            <Button
              type="submit"
              disabled={passcodeLoading || !passcode}
              className="h-11 w-full rounded-2xl brand-gradient font-display text-sm font-bold text-white shadow-lg shadow-brand-purple/25 transition hover:opacity-95 disabled:opacity-50"
            >
              {passcodeLoading ? "Saving…" : "Set passcode"}
            </Button>

            <button
              type="button"
              onClick={handleRemovePasscode}
              disabled={passcodeLoading}
              className="h-11 w-full rounded-2xl border border-white/10 bg-white/5 font-display text-xs font-semibold text-zinc-300 transition hover:bg-white/10 hover:text-white disabled:opacity-50"
            >
              Remove passcode
            </button>
          </div>
        </form>
      </div>
    </AuthGuard>
  );
}
