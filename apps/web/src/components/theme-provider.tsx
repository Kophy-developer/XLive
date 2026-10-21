"use client";

import { useEffect } from "react";
import { useUiStore } from "@/lib/stores";

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const theme = useUiStore((s) => s.theme);

  useEffect(() => {
    const root = document.documentElement;
    const isLight = theme === "light";
    root.classList.toggle("light", isLight);
    root.classList.toggle("dark", !isLight);
  }, [theme]);

  return <>{children}</>;
}
