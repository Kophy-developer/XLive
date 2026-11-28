"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { GuestGuard } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  checkAvailability,
  createAccount,
  normalizeAuthPhone,
  PASSWORD_MIN_LENGTH,
  passwordRuleError,
  serverPasswordError,
  resendVerification,
  verifyEmail,
} from "@/lib/api/auth";
import { connectSocket } from "@/lib/socket";
import { useAuthStore } from "@/lib/stores";
import { getMe } from "@/lib/api/auth";

type Step = "details" | "verify" | "done";

function CreateAccountForm() {
  const router = useRouter();
  const params = useSearchParams();
  const verifyIdentifier = params.get("verify");
  const { setUser, setAuthenticated } = useAuthStore();
  const [step, setStep] = useState<Step>(verifyIdentifier ? "verify" : "details");
  const [form, setForm] = useState({
    firstName: "",
    lastName: "",
    username: "",
    email: "",
    phone: "",
    password: "",
    code: "",
  });
  const [identifier, setIdentifier] = useState(verifyIdentifier ?? "");
  const [error, setError] = useState("");
  const [info, setInfo] = useState(
    verifyIdentifier && params.get("sent") ? `We sent a new 6-digit code to ${verifyIdentifier}.` : ""
  );
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [serverPwError, setServerPwError] = useState("");
  const pwError = serverPwError || (form.password ? passwordRuleError(form.password) : null);

  function update(field: string, value: string) {
    setForm((f) => ({ ...f, [field]: value }));
    if (field === "password") setServerPwError("");
  }

  async function handleDetails(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    if (pwError) return;
    setLoading(true);
    try {
      const phone = form.phone.trim() ? normalizeAuthPhone(form.phone) : "";
      if (form.phone.trim() && !phone) {
        setError("Enter a valid phone number");
        return;
      }
      await checkAvailability({ email: form.email, phone: phone || undefined });
      await createAccount({
        firstName: form.firstName,
        lastName: form.lastName,
        username: form.username,
        email: form.email,
        phone,
        password: form.password,
      });
      // POST /auth/create emails a 6-digit code; no token until the email is verified.
      setIdentifier(form.email.trim());
      setInfo(`We sent a 6-digit code to ${form.email.trim()}. Check your inbox and spam.`);
      setStep("verify");
    } catch (err) {
      const pwServer = serverPasswordError(err);
      if (pwServer) setServerPwError(pwServer);
      else setError((err as Error).message || "Registration failed");
    } finally {
      setLoading(false);
    }
  }

  async function handleVerify(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const email = (identifier || form.email).trim();
      if (!email.includes("@")) {
        setError("Missing email address. Go back and sign in with your email.");
        return;
      }
      const code = form.code.replace(/\D/g, "");
      if (code.length !== 6) {
        setError("Enter the 6-digit code from your email.");
        return;
      }
      await verifyEmail(email, code);
      const user = await getMe();
      setUser(user);
      setAuthenticated(true);
      connectSocket();
      router.push("/home");
    } catch (err) {
      setError((err as Error).message || "Verification failed");
    } finally {
      setLoading(false);
    }
  }

  async function handleResend() {
    const email = (identifier || form.email).trim();
    if (!email.includes("@")) return;
    setError("");
    setInfo("");
    setResending(true);
    try {
      await resendVerification(email);
      setInfo(`A new code was sent to ${email}.`);
    } catch (err) {
      setError((err as Error).message || "Could not resend code");
    } finally {
      setResending(false);
    }
  }

  return (
    <div className="mx-auto flex min-h-dvh max-w-md flex-col justify-center px-6 animate-slide-up">
      <Link href="/onboarding" className="mb-6 inline-block">
        <img src="/logo.png" alt="XLive" className="h-12 w-auto object-contain" />
      </Link>
      <h1 className="font-display text-2xl font-semibold">
        {step === "verify" ? "Verify your account" : "Create account"}
      </h1>
      {step === "details" ? (
        <form onSubmit={handleDetails} className="mt-8 space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <Input placeholder="First name" value={form.firstName} onChange={(e) => update("firstName", e.target.value)} required />
            <Input placeholder="Last name" value={form.lastName} onChange={(e) => update("lastName", e.target.value)} required />
          </div>
          <Input placeholder="Username" value={form.username} onChange={(e) => update("username", e.target.value)} required />
          <Input type="email" placeholder="Email" value={form.email} onChange={(e) => update("email", e.target.value)} required />
          <Input
            placeholder="Phone (e.g. 0903… or +234…)"
            value={form.phone}
            onChange={(e) => update("phone", e.target.value)}
            required
          />
          <Input type="password" placeholder={`Password (at least ${PASSWORD_MIN_LENGTH} characters)`} value={form.password} onChange={(e) => update("password", e.target.value)} required aria-invalid={Boolean(pwError)} />
          {pwError ? <p className="text-sm text-red-500">{pwError}</p> : null}
          {error ? <p className="text-sm text-red-500">{error}</p> : null}
          <Button type="submit" className="w-full" disabled={loading}>{loading ? "Creating…" : "Continue"}</Button>
        </form>
      ) : (
        <form onSubmit={handleVerify} className="mt-8 space-y-4">
          <p className="text-sm text-muted">Enter the code sent to {identifier}</p>
          <Input
            placeholder="6-digit code"
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            value={form.code}
            onChange={(e) => update("code", e.target.value.replace(/\D/g, ""))}
            required
          />
          {info ? <p className="text-sm text-muted">{info}</p> : null}
          {error ? <p className="text-sm text-red-500">{error}</p> : null}
          <Button type="submit" className="w-full" disabled={loading || resending}>{loading ? "Verifying…" : "Verify & sign in"}</Button>
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
      <p className="mt-6 text-center text-sm text-muted">
        Already have an account?{" "}
        <Link href="/auth/sign-in" className="text-accent hover:underline">Sign in</Link>
      </p>
    </div>
  );
}

export default function CreateAccountPage() {
  return (
    <GuestGuard>
      <Suspense>
        <CreateAccountForm />
      </Suspense>
    </GuestGuard>
  );
}
