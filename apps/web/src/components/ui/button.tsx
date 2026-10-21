import { cn } from "@/lib/utils";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { forwardRef } from "react";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 rounded-2xl font-semibold transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-purple disabled:pointer-events-none disabled:opacity-50 active:scale-[0.98]",
  {
    variants: {
      variant: {
        default: "brand-gradient text-white shadow-lg shadow-brand-purple/20 hover:opacity-95",
        secondary: "bg-surface-hover/80 border border-border/80 text-foreground hover:bg-surface-hover",
        ghost: "hover:bg-surface-hover text-foreground",
        destructive: "bg-red-600 text-white hover:bg-red-700 shadow-md shadow-red-600/20",
      },
      size: {
        default: "h-11 px-5 text-sm",
        sm: "h-9 px-3.5 text-xs",
        lg: "h-12 px-6 text-base",
        icon: "h-10 w-10",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  }
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return <Comp className={cn(buttonVariants({ variant, size, className }))} ref={ref} {...props} />;
  }
);
Button.displayName = "Button";
