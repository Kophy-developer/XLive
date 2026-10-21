"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/lib/stores";

export default function SplashPage() {
  const router = useRouter();
  const { isAuthenticated, isLoading } = useAuthStore();

  useEffect(() => {
    if (isLoading) return;
    if (isAuthenticated) {
      router.replace("/home");
    } else {
      router.replace("/onboarding");
    }
  }, [isAuthenticated, isLoading, router]);

  return (
    <div className="flex min-h-dvh flex-col items-center justify-center gap-6 animate-fade-in">
      <img src="/logo.png" alt="XLive" className="h-16 w-auto object-contain" />
      <div className="h-2 w-2 animate-pulse rounded-full brand-gradient" />
    </div>
  );
}
