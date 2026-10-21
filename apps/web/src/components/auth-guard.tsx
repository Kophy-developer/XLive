"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { useAuthStore } from "@/lib/stores";
import { AccountChip } from "./account-chip";
import { AppShell } from "./app-shell";

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { isAuthenticated, isLoading } = useAuthStore();

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.replace("/auth/sign-in");
    }
  }, [isAuthenticated, isLoading, router]);

  if (isLoading) {
    return (
      <div className="flex min-h-dvh items-center justify-center">
        <div className="h-10 w-10 animate-pulse rounded-full brand-gradient" />
      </div>
    );
  }

  if (!isAuthenticated) return null;

  return <AppShell>{children}</AppShell>;
}

export function GuestGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { isAuthenticated, isLoading } = useAuthStore();

  useEffect(() => {
    if (!isLoading && isAuthenticated) {
      router.replace("/home");
    }
  }, [isAuthenticated, isLoading, router]);

  if (isLoading) {
    return (
      <div className="flex min-h-dvh items-center justify-center">
        <div className="h-10 w-10 animate-pulse rounded-full brand-gradient" />
      </div>
    );
  }

  if (isAuthenticated) return null;

  return <>{children}</>;
}

export function PageHeader({
  title,
  backHref,
  action,
}: {
  title: string;
  backHref?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="sticky top-0 z-20 flex items-center justify-between border-b border-border/70 bg-surface/80 px-4 py-3 backdrop-blur-xl">
      <div className="flex items-center gap-3">
        {backHref ? (
          <Link
            href={backHref}
            className="flex items-center gap-1 rounded-xl px-2.5 py-1 text-xs font-semibold text-muted transition hover:bg-surface-hover hover:text-foreground"
          >
            ← Back
          </Link>
        ) : null}
        <h1 className="font-display text-base font-bold tracking-tight text-foreground">{title}</h1>
      </div>
      <div className="flex items-center gap-2">
        {action}
        <AccountChip className="hidden md:flex" />
      </div>
    </div>
  );
}
