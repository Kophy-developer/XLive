"use client";

import * as Dialog from "@radix-ui/react-dialog";
import Link from "next/link";
import { Camera, Film, Radio, X } from "lucide-react";
import { useUiStore } from "@/lib/stores";

const options = [
  {
    href: "/create",
    label: "Create Post",
    icon: Camera,
    desc: "Share photos and videos with followers",
  },
  {
    href: "/live/setup",
    label: "Go Live",
    icon: Radio,
    desc: "Start an interactive real-time broadcast",
  },
  {
    href: "/create?type=collectible",
    label: "Mint Collectible Clip",
    icon: Film,
    desc: "Sell exclusive collectible moments to fans",
  },
];

export function CreateSheet() {
  const open = useUiStore((s) => s.createSheetOpen);
  const setOpen = useUiStore((s) => s.setCreateSheetOpen);

  return (
    <Dialog.Root open={open} onOpenChange={setOpen}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 z-50 bg-black/75 backdrop-blur-md animate-fade-in" />
        <Dialog.Content className="fixed bottom-0 left-0 right-0 z-50 rounded-t-[32px] border border-white/10 bg-[#141420]/95 p-6 backdrop-blur-2xl shadow-2xl animate-slide-up md:bottom-auto md:left-1/2 md:top-1/2 md:w-full md:max-w-md md:-translate-x-1/2 md:-translate-y-1/2 md:rounded-3xl">
          <div className="mb-5 flex items-center justify-between">
            <Dialog.Title className="font-display text-lg font-bold text-white">
              Create New
            </Dialog.Title>
            <Dialog.Close className="flex h-8 w-8 items-center justify-center rounded-full bg-white/5 text-zinc-400 hover:bg-white/10 hover:text-white transition">
              <X className="h-4 w-4" />
            </Dialog.Close>
          </div>

          <div className="space-y-2.5">
            {options.map((opt) => (
              <Link
                key={opt.href}
                href={opt.href}
                onClick={() => setOpen(false)}
                className="group flex items-center gap-4 rounded-2xl border border-white/10 bg-white/5 p-4 transition hover:border-brand-purple/40 hover:bg-brand-purple/10"
              >
                <div className="flex h-12 w-12 items-center justify-center rounded-2xl brand-gradient text-white shadow-lg shadow-brand-purple/20 transition group-hover:scale-105">
                  <opt.icon className="h-6 w-6" />
                </div>
                <div>
                  <p className="font-display text-sm font-bold text-white group-hover:text-brand-purple transition-colors">
                    {opt.label}
                  </p>
                  <p className="text-xs text-zinc-400">{opt.desc}</p>
                </div>
              </Link>
            ))}
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
