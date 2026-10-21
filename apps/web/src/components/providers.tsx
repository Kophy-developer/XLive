"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState, type ReactNode } from "react";
import { AuthProvider } from "./auth-provider";
import { IncomingCallDialog, OngoingCallBanner } from "./incoming-call-dialog";
import { MobileAppGate } from "./mobile-app-gate";
import { StreamInviteDialog } from "./stream-invite-dialog";
import { ThemeProvider } from "./theme-provider";

export function Providers({ children }: { children: ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 30_000,
            retry: 1,
          },
        },
      })
  );

  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <AuthProvider>
          {children}
          <IncomingCallDialog />
          <OngoingCallBanner />
          <StreamInviteDialog />
          <MobileAppGate />
        </AuthProvider>
      </ThemeProvider>
    </QueryClientProvider>
  );
}
