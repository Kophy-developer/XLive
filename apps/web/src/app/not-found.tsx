import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function NotFound() {
  return (
    <div className="flex min-h-dvh flex-col items-center justify-center px-6 text-center animate-fade-in">
      <p className="font-display text-6xl font-bold brand-text">404</p>
      <h1 className="mt-4 font-display text-2xl font-semibold">Page not found</h1>
      <p className="mt-2 text-muted">This route doesn&apos;t exist on XLive web.</p>
      <Button asChild className="mt-8">
        <Link href="/home">Go home</Link>
      </Button>
    </div>
  );
}
