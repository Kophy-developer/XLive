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
  login,
  requestVerification,
  verifyCode,
  completeAuth,
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
  const [loading, setLoading] = useState(false);

  function update(field: string, value: string) {
    setForm((f) => ({ ...f, [field]: value }));
  }

  async function handleDetails(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await checkAvailability({ email: form.email, username: form.username, phone: form.phone });
      await createAccount({
        firstName: form.firstName,
        lastName: form.lastName,
        username: form.username,
        email: form.email,
        phone: form.phone,
        password: form.password,
      });
      setIdentifier(form.email || form.phone);
      await requestVerification({ identifier: form.email || form.phone, type: form.email ? "email" : "phone" });
      setStep("verify");
    } catch (err) {
      setError((err as Error).message || "Registration failed");
    } finally {
      setLoading(false);
    }
  }

  async function handleVerify(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const id = identifier || form.email || form.phone;
      await verifyCode({ identifier: id, code: form.code });
      const loginResult = await login(id, form.password);
      await completeAuth(loginResult);
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
          <Input placeholder="Phone" value={form.phone} onChange={(e) => update("phone", e.target.value)} />
          <Input type="password" placeholder="Password (at least 8 characters)" value={form.password} onChange={(e) => update("password", e.target.value)} required minLength={8} />
          {error ? <p className="text-sm text-red-500">{error}</p> : null}
          <Button type="submit" className="w-full" disabled={loading}>{loading ? "Creating…" : "Continue"}</Button>
        </form>
      ) : (
        <form onSubmit={handleVerify} className="mt-8 space-y-4">
          <p className="text-sm text-muted">Enter the code sent to {identifier}</p>
          <Input placeholder="Verification code" value={form.code} onChange={(e) => update("code", e.target.value)} required />
          {error ? <p className="text-sm text-red-500">{error}</p> : null}
          <Button type="submit" className="w-full" disabled={loading}>{loading ? "Verifying…" : "Verify & sign in"}</Button>
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
