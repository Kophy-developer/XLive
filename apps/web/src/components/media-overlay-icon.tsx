import { cn } from "@/lib/utils";
import type { ReactNode } from "react";

export function MediaOverlayIcon({
  children,
  className,
  size = "md",
}: {
  children: ReactNode;
  className?: string;
  size?: "sm" | "md";
}) {
  const dim = size === "sm" ? "h-8 w-8" : "h-9 w-9";
  return (
    <span
      className={cn(
        "inline-flex items-center justify-center rounded-full bg-black/40 shadow-[0_2px_10px_rgba(0,0,0,0.28)] backdrop-blur-[2px]",
        dim,
        className
      )}
    >
      {children}
    </span>
  );
}
