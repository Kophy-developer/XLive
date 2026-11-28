"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { GuestGuard } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PASSWORD_MIN_LENGTH, passwordRuleError, requestPasswordReset, resetPassword, serverPasswordError } from "@/lib/api/auth";

type Step = "request" | "reset";

export default function ForgotPasswordPage() {
  const router = useRouter();
  const [step, setStep] = useState<Step>("request");
  const [identifier, setIdentifier] = useState("");
  const [code, setCode] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [serverPwError, setServerPwError] = useState("");
  const pwError = serverPwError || (password ? passwordRuleError(password) : null);

  async function handleRequest(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setInfo("");
    setLoading(true);
    try {
      await requestPasswordReset(identifier);
      setInfo(`Reset code sent to ${identifier.trim()}. Check inbox and spam.`);
      setStep("reset");
    } catch (err) {
      setError((err as Error).message || "Request failed");
    } finally {
      setLoading(false);
    }
  }

  async function handleResend() {
    setError("");
    setInfo("");
    setResending(true);
    try {
      await requestPasswordReset(identifier);
      setInfo(`Reset code resent to ${identifier.trim()}. Check inbox and spam.`);
    } catch (err) {
      setError((err as Error).message || "Could not resend code");
    } finally {
      setResending(false);
    }
  }

  async function handleReset(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setInfo("");
    if (pwError) return;
    setLoading(true);
    try {
      await resetPassword({ email: identifier, code, newPassword: password });
      router.push("/auth/sign-in");
    } catch (err) {
      const pwServer = serverPasswordError(err);
      if (pwServer) setServerPwError(pwServer);
      else setError((err as Error).message || "Reset failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <GuestGuard>
      <div className="mx-auto flex min-h-dvh max-w-md flex-col justify-center px-6 animate-slide-up">
        <Link href="/auth/sign-in" className="mb-8 text-sm text-muted hover:text-foreground">← Back to sign in</Link>
        <h1 className="font-display text-2xl font-semibold">Reset password</h1>
        {step === "request" ? (
          <form onSubmit={handleRequest} className="mt-8 space-y-4">
            <Input type="email" placeholder="Email" value={identifier} onChange={(e) => setIdentifier(e.target.value)} required />
            {error ? <p className="text-sm text-red-500">{error}</p> : null}
            <Button type="submit" className="w-full" disabled={loading}>{loading ? "Sending…" : "Send reset code"}</Button>
          </form>
        ) : (
          <form onSubmit={handleReset} className="mt-8 space-y-4">
            <p className="text-sm text-muted">Enter the code sent to {identifier}</p>
            <Input placeholder="Reset code" value={code} onChange={(e) => setCode(e.target.value)} required />
            <Input
              type="password"
              placeholder={`New password (at least ${PASSWORD_MIN_LENGTH} characters)`}
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                setServerPwError("");
              }}
              required
              aria-invalid={Boolean(pwError)}
            />
            {pwError ? <p className="text-sm text-red-500">{pwError}</p> : null}
            {info ? <p className="text-sm text-muted">{info}</p> : null}
            {error ? <p className="text-sm text-red-500">{error}</p> : null}
            <Button type="submit" className="w-full" disabled={loading || resending}>
              {loading ? "Resetting…" : "Reset password"}
            </Button>
            <button
              type="button"
              onClick={handleResend}
              disabled={loading || resending}
              className="w-full text-center text-sm font-medium text-brand-purple hover:underline disabled:opacity-50"
            >
              {resending ? "Resending…" : "Resend code"}
            </button>
          </form>
        )}
      </div>
    </GuestGuard>
  );
}
