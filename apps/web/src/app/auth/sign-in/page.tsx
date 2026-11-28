"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { GuestGuard } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { EmailNotVerifiedError, resendVerification, signIn, getMe } from "@/lib/api/auth";
import { connectSocket } from "@/lib/socket";
import { useAuthStore } from "@/lib/stores";
import { Lock, User, ArrowRight } from "lucide-react";

export default function SignInPage() {
  const router = useRouter();
  const { setUser, setAuthenticated } = useAuthStore();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await signIn(identifier, password);
      const user = await getMe();
      setUser(user);
      setAuthenticated(true);
      connectSocket();
      router.push("/home");
    } catch (err) {
      if (err instanceof EmailNotVerifiedError) {
        // The 403 sends no code (verificationSent: false), so send one, then open the verify step.
        await resendVerification(err.email);
        router.push(`/auth/create-account?verify=${encodeURIComponent(err.email)}&sent=1`);
        return;
      }
      setError((err as Error).message || "Sign in failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <GuestGuard>
      <div className="flex min-h-dvh flex-col justify-center px-4 py-12 sm:px-6 lg:px-8">
        <div className="mx-auto w-full max-w-sm text-center">
          <Link href="/onboarding" className="inline-block">
            <img src="/logo.png" alt="XLive" className="h-14 w-auto object-contain mx-auto" />
          </Link>
          <h1 className="mt-4 font-display text-2xl font-bold tracking-tight text-foreground">Welcome back</h1>
          <p className="mt-1 text-xs text-muted">Sign in with your mobile username or email</p>
        </div>

        <div className="mx-auto mt-6 w-full max-w-sm rounded-3xl border border-border/80 bg-surface/80 p-6 backdrop-blur-xl shadow-xl shadow-brand-purple/5">
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold uppercase tracking-wider text-muted">Account</label>
              <div className="relative">
                <User className="absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
                <Input
                  placeholder="Username, email, or phone"
                  value={identifier}
                  onChange={(e) => setIdentifier(e.target.value)}
                  required
                  autoCapitalize="none"
                  autoCorrect="off"
                  className="h-11 rounded-2xl bg-surface-hover/60 pl-10 border-border/60 focus-visible:ring-brand-purple"
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <label className="text-xs font-semibold uppercase tracking-wider text-muted">Password</label>
                <Link href="/auth/forgot-password" className="text-xs font-medium text-brand-purple hover:underline">
                  Forgot?
                </Link>
              </div>
              <div className="relative">
                <Lock className="absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
                <Input
                  type="password"
                  placeholder="Enter your password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="h-11 rounded-2xl bg-surface-hover/60 pl-10 border-border/60 focus-visible:ring-brand-purple"
                />
              </div>
            </div>

            {error ? (
              <div className="rounded-xl bg-red-500/10 p-3 text-xs font-medium text-red-400">
                {error}
              </div>
            ) : null}

            <Button
              type="submit"
              className="h-11 w-full rounded-2xl brand-gradient font-display text-sm font-bold text-white shadow-lg shadow-brand-purple/20 transition hover:opacity-95 disabled:opacity-40"
              disabled={loading}
            >
              {loading ? (
                <span className="flex items-center gap-2">
                  <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                  Signing in…
                </span>
              ) : (
                <span className="flex items-center gap-1.5">
                  Sign In <ArrowRight className="h-4 w-4" />
                </span>
              )}
            </Button>
          </form>

          <div className="mt-6 border-t border-border/60 pt-4 text-center text-xs text-muted">
            New to XLive?{" "}
            <Link href="/auth/create-account" className="font-semibold text-brand-purple hover:underline">
              Create an account
            </Link>
          </div>
        </div>
      </div>
    </GuestGuard>
  );
}
