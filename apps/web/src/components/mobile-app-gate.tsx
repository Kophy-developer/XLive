"use client";

import { useState } from "react";
import {
  Smartphone,
  Download,
  Apple,
  Sparkles,
  Radio,
  Video,
  MessageCircle,
  Coins,
  ChevronRight,
  X,
} from "lucide-react";

export function MobileAppGate() {
  const [dismissed, setDismissed] = useState(false);
  const [showAndroidModal, setShowAndroidModal] = useState(false);
  const [showIosModal, setShowIosModal] = useState(false);

  if (dismissed) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-[99999] flex flex-col justify-between overflow-y-auto bg-[#07070c] px-6 py-8 text-center text-white md:hidden">
      <div className="pointer-events-none absolute inset-0 -z-10 overflow-hidden">
        <div className="absolute -top-32 left-1/2 h-96 w-96 -translate-x-1/2 rounded-full bg-brand-purple/25 blur-3xl" />
        <div className="absolute bottom-0 right-0 h-80 w-80 rounded-full bg-brand-sky/15 blur-3xl" />
      </div>

      <div className="flex flex-col items-center">
        <div className="flex items-center justify-center gap-2">
          <img src="/logo.png" alt="XLive" className="h-10 w-auto object-contain" />
        </div>
        <div className="mt-4 inline-flex items-center gap-1.5 rounded-full border border-brand-purple/40 bg-brand-purple/15 px-3 py-1 text-xs font-semibold text-brand-purple shadow-sm">
          <Sparkles className="h-3.5 w-3.5" />
          <span>Mobile App Experience</span>
        </div>
      </div>

      <div className="my-6 flex flex-col items-center">
        <div className="relative mb-5 flex h-24 w-24 items-center justify-center rounded-3xl border border-white/10 bg-gradient-to-br from-white/10 via-brand-purple/20 to-transparent p-1 shadow-2xl backdrop-blur-2xl">
          <div className="flex h-full w-full items-center justify-center rounded-[22px] bg-[#12121e]">
            <Smartphone className="h-10 w-10 text-brand-purple" />
          </div>
          <span className="absolute -bottom-1 -right-1 flex h-6 w-6 items-center justify-center rounded-full brand-gradient text-[10px] font-black text-white shadow-lg">
            HD
          </span>
        </div>

        <h1 className="font-sans text-2xl font-black tracking-tight text-white sm:text-3xl">
          Download the XLive App
        </h1>
        <p className="mt-2.5 max-w-xs text-xs font-normal leading-relaxed text-zinc-300">
          XLive Web is designed for iPads, tablets, and desktop computers. For the best mobile experience, download the native XLive app on your phone.
        </p>

        <div className="mt-6 grid w-full max-w-xs grid-cols-2 gap-2 text-left">
          <div className="flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 p-2.5 backdrop-blur-md">
            <Radio className="h-4 w-4 shrink-0 text-red-500" />
            <span className="text-[11px] font-semibold text-zinc-200">Live Streaming</span>
          </div>
          <div className="flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 p-2.5 backdrop-blur-md">
            <Video className="h-4 w-4 shrink-0 text-brand-sky" />
            <span className="text-[11px] font-semibold text-zinc-200">Video & Voice Calls</span>
          </div>
          <div className="flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 p-2.5 backdrop-blur-md">
            <MessageCircle className="h-4 w-4 shrink-0 text-brand-purple" />
            <span className="text-[11px] font-semibold text-zinc-200">Instant Messaging</span>
          </div>
          <div className="flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 p-2.5 backdrop-blur-md">
            <Coins className="h-4 w-4 shrink-0 text-amber-400" />
            <span className="text-[11px] font-semibold text-zinc-200">Creator Wallet</span>
          </div>
        </div>
      </div>

      <div className="flex w-full flex-col items-center gap-3">
        <button
          type="button"
          onClick={() => setShowAndroidModal(true)}
          className="flex w-full max-w-xs items-center justify-between rounded-2xl brand-gradient px-5 py-3.5 font-display text-sm font-bold text-white shadow-xl shadow-brand-purple/25 transition hover:opacity-95 active:scale-[0.98]"
        >
          <div className="flex items-center gap-3">
            <Download className="h-5 w-5" />
            <div className="text-left leading-tight">
              <div className="text-[10px] uppercase tracking-wider text-white/80">Get it on</div>
              <div>Download for Android (.APK)</div>
            </div>
          </div>
          <ChevronRight className="h-4 w-4 opacity-75" />
        </button>

        <button
          type="button"
          onClick={() => setShowIosModal(true)}
          className="flex w-full max-w-xs items-center justify-between rounded-2xl border border-white/15 bg-white/10 px-5 py-3.5 font-display text-sm font-bold text-white backdrop-blur-xl transition hover:bg-white/15 active:scale-[0.98]"
        >
          <div className="flex items-center gap-3">
            <Apple className="h-5 w-5" />
            <div className="text-left leading-tight">
              <div className="text-[10px] uppercase tracking-wider text-white/70">Apple iOS</div>
              <div>Download on App Store / TestFlight</div>
            </div>
          </div>
          <ChevronRight className="h-4 w-4 opacity-75" />
        </button>

        <button
          type="button"
          onClick={() => setDismissed(true)}
          className="mt-2 text-xs font-medium text-zinc-500 underline underline-offset-4 transition hover:text-zinc-300"
        >
          Continue in mobile browser
        </button>
      </div>

      {showAndroidModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-5 backdrop-blur-md">
          <div className="relative w-full max-w-sm rounded-3xl border border-white/10 bg-[#141422] p-6 text-center shadow-2xl">
            <button
              type="button"
              onClick={() => setShowAndroidModal(false)}
              className="absolute right-4 top-4 flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-zinc-400 hover:text-white"
            >
              <X className="h-4 w-4" />
            </button>
            <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl brand-gradient text-white">
              <Download className="h-7 w-7" />
            </div>
            <h3 className="mt-4 font-sans text-lg font-bold text-white">Android APK Download</h3>
            <p className="mt-2 text-xs leading-relaxed text-zinc-300">
              Download the official XLive Android release APK for the latest streaming, 4-host co-hosting, and instant call features.
            </p>
            <div className="mt-5 flex flex-col gap-2">
              <a
                href="https://store-x-live.4tqepo.easypanel.host/download/app"
                target="_blank"
                rel="noreferrer"
                className="flex items-center justify-center gap-2 rounded-xl brand-gradient py-3 text-xs font-bold text-white shadow-lg shadow-brand-purple/20"
              >
                <Download className="h-4 w-4" />
                <span>Download Latest APK</span>
              </a>
              <button
                type="button"
                onClick={() => setShowAndroidModal(false)}
                className="rounded-xl border border-white/10 py-2.5 text-xs font-semibold text-zinc-400 hover:text-white"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {showIosModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-5 backdrop-blur-md">
          <div className="relative w-full max-w-sm rounded-3xl border border-white/10 bg-[#141422] p-6 text-center shadow-2xl">
            <button
              type="button"
              onClick={() => setShowIosModal(false)}
              className="absolute right-4 top-4 flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-zinc-400 hover:text-white"
            >
              <X className="h-4 w-4" />
            </button>
            <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-white/10 text-white">
              <Apple className="h-7 w-7" />
            </div>
            <h3 className="mt-4 font-sans text-lg font-bold text-white">iOS App Access</h3>
            <p className="mt-2 text-xs leading-relaxed text-zinc-300">
              The XLive iOS App is available via TestFlight and Apple App Store for registered beta testers and early access members.
            </p>
            <div className="mt-5 flex flex-col gap-2">
              <a
                href="https://testflight.apple.com"
                target="_blank"
                rel="noreferrer"
                className="flex items-center justify-center gap-2 rounded-xl bg-white text-black py-3 text-xs font-bold shadow-lg"
              >
                <Apple className="h-4 w-4" />
                <span>Open in TestFlight</span>
              </a>
              <button
                type="button"
                onClick={() => setShowIosModal(false)}
                className="rounded-xl border border-white/10 py-2.5 text-xs font-semibold text-zinc-400 hover:text-white"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
