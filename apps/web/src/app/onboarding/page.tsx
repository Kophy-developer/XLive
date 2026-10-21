"use client";

import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function OnboardingPage() {
  return (
    <div className="flex min-h-dvh flex-col items-center justify-center px-6 text-center animate-fade-in">
      <img src="/logo.png" alt="XLive" className="mb-8 h-20 w-auto object-contain mx-auto" />
      <h1 className="font-display text-3xl font-semibold">Go live. Create. Connect.</h1>
      <p className="mt-3 max-w-md text-muted">
        Stream to the world, mint collectible clips, and chat with your community — all in one place.
      </p>
      <div className="mt-10 flex w-full max-w-sm flex-col gap-3">
        <Button asChild size="lg">
          <Link href="/auth/create-account">Create account</Link>
        </Button>
        <Button asChild variant="secondary" size="lg">
          <Link href="/auth/sign-in">Sign in</Link>
        </Button>
      </div>
    </div>
  );
}
