"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { GuestGuard } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { requestPasswordReset, resetPassword } from "@/lib/api/auth";

type Step = "request" | "reset";

export default function ForgotPasswordPage() {
  const router = useRouter();
  const [step, setStep] = useState<Step>("request");
  const [identifier, setIdentifier] = useState("");
  const [code, setCode] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleRequest(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await requestPasswordReset(identifier);
      setStep("reset");
    } catch (err) {
      setError((err as Error).message || "Request failed");
    } finally {
      setLoading(false);
    }
  }

  async function handleReset(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await resetPassword({ identifier, code, password });
      router.push("/auth/sign-in");
    } catch (err) {
      setError((err as Error).message || "Reset failed");
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
            <Input placeholder="Email, username, or phone" value={identifier} onChange={(e) => setIdentifier(e.target.value)} required />
            {error ? <p className="text-sm text-red-500">{error}</p> : null}
            <Button type="submit" className="w-full" disabled={loading}>{loading ? "Sending…" : "Send reset code"}</Button>
          </form>
        ) : (
          <form onSubmit={handleReset} className="mt-8 space-y-4">
            <Input placeholder="Reset code" value={code} onChange={(e) => setCode(e.target.value)} required />
            <Input type="password" placeholder="New password (at least 8 characters)" value={password} onChange={(e) => setPassword(e.target.value)} required minLength={8} />
            {error ? <p className="text-sm text-red-500">{error}</p> : null}
            <Button type="submit" className="w-full" disabled={loading}>{loading ? "Resetting…" : "Reset password"}</Button>
          </form>
        )}
      </div>
    </GuestGuard>
  );
}
