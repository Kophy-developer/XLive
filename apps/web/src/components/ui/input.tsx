import { cn } from "@/lib/utils";
import { forwardRef } from "react";

export const Input = forwardRef<HTMLInputElement, React.InputHTMLAttributes<HTMLInputElement>>(
  ({ className, ...props }, ref) => (
    <input
      ref={ref}
      className={cn(
        "flex h-11 w-full rounded-2xl border border-white/10 bg-[#161622] px-4 text-sm font-medium text-white placeholder:text-zinc-400 transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-purple/50 focus-visible:border-brand-purple",
        className
      )}
      {...props}
    />
  )
);
Input.displayName = "Input";

export const Textarea = forwardRef<HTMLTextAreaElement, React.TextareaHTMLAttributes<HTMLTextAreaElement>>(
  ({ className, ...props }, ref) => (
    <textarea
      ref={ref}
      className={cn(
        "flex min-h-[100px] w-full rounded-2xl border border-white/10 bg-[#161622] px-4 py-3 text-sm font-medium text-white placeholder:text-zinc-400 transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-purple/50 focus-visible:border-brand-purple",
        className
      )}
      {...props}
    />
  )
);
Textarea.displayName = "Textarea";
