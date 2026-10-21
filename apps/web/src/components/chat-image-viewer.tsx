"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { ChevronLeft, ChevronRight, X } from "lucide-react";
import { cloudinaryUrl, cn, originalMediaUrl } from "@/lib/utils";

function Tile({
  url,
  className,
  overlay,
  onClick,
}: {
  url: string;
  className?: string;
  overlay?: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn("relative m-0 block h-full w-full overflow-hidden border-0 bg-black/40 p-0", className)}
    >
      <img src={cloudinaryUrl(url, "c_fill,w_800,h_800,g_auto")} alt="" className="h-full w-full object-cover" />
      {overlay ? (
        <span className="absolute inset-0 flex items-center justify-center bg-black/55 text-2xl font-bold text-white">
          {overlay}
        </span>
      ) : null}
    </button>
  );
}

export function ChatImageCollage({
  urls,
  onOpen,
}: {
  urls: string[];
  onOpen: (index: number) => void;
}) {
  if (!urls.length) return null;
  if (urls.length === 1) {
    return (
      <button type="button" onClick={() => onOpen(0)} className="block w-full overflow-hidden p-0">
        <img
          src={cloudinaryUrl(urls[0], "c_fill,w_900,h_900,g_auto")}
          alt=""
          className="max-h-80 w-full object-cover"
        />
      </button>
    );
  }
  if (urls.length === 2) {
    return (
      <div className="grid h-[220px] w-full grid-cols-2 gap-0.5 bg-black/30">
        {urls.map((url, index) => (
          <Tile key={`${url}-${index}`} url={url} onClick={() => onOpen(index)} />
        ))}
      </div>
    );
  }
  if (urls.length === 3) {
    return (
      <div className="grid h-[280px] w-full grid-cols-2 grid-rows-2 gap-0.5 bg-black/30">
        <Tile url={urls[0]} className="row-span-2" onClick={() => onOpen(0)} />
        <Tile url={urls[1]} onClick={() => onOpen(1)} />
        <Tile url={urls[2]} onClick={() => onOpen(2)} />
      </div>
    );
  }
  const extra = urls.length - 4;
  return (
    <div className="grid h-[280px] w-full grid-cols-2 grid-rows-2 gap-0.5 bg-black/30">
      {urls.slice(0, 4).map((url, index) => (
        <Tile
          key={`${url}-${index}`}
          url={url}
          overlay={index === 3 && extra > 0 ? `+${extra}` : undefined}
          onClick={() => onOpen(index)}
        />
      ))}
    </div>
  );
}

export function ChatPhotoViewer({
  urls,
  index,
  onClose,
  onIndex,
}: {
  urls: string[];
  index: number;
  onClose: () => void;
  onIndex: (index: number) => void;
}) {
  const current = urls[index];
  const canPrev = index > 0;
  const canNext = index < urls.length - 1;
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    if (!mounted) return;
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
      if (e.key === "ArrowLeft" && canPrev) onIndex(index - 1);
      if (e.key === "ArrowRight" && canNext) onIndex(index + 1);
    };
    window.addEventListener("keydown", onKey);
    return () => {
      document.body.style.overflow = prevOverflow;
      window.removeEventListener("keydown", onKey);
    };
  }, [canNext, canPrev, index, mounted, onClose, onIndex]);

  if (!mounted || !current) return null;

  return createPortal(
    <div
      onClick={onClose}
      style={{
        position: "fixed",
        top: 0,
        right: 0,
        bottom: 0,
        left: 0,
        width: "100vw",
        height: "100dvh",
        zIndex: 2147483000,
        backgroundColor: "rgba(0, 0, 0, 0.88)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation();
          onClose();
        }}
        className="flex h-11 w-11 items-center justify-center rounded-full bg-black text-white shadow-lg ring-2 ring-white/80 hover:bg-zinc-800"
        style={{ position: "absolute", top: 20, right: 20 }}
      >
        <X className="h-5 w-5" />
      </button>
      {canPrev ? (
        <button
          type="button"
          onClick={(e) => {
            e.stopPropagation();
            onIndex(index - 1);
          }}
          className="flex h-12 w-12 items-center justify-center rounded-full bg-black text-white shadow-lg ring-2 ring-white/80 hover:bg-zinc-800"
          style={{ position: "absolute", left: 24, top: "50%", transform: "translateY(-50%)" }}
        >
          <ChevronLeft className="h-7 w-7" />
        </button>
      ) : null}
      {canNext ? (
        <button
          type="button"
          onClick={(e) => {
            e.stopPropagation();
            onIndex(index + 1);
          }}
          className="flex h-12 w-12 items-center justify-center rounded-full bg-black text-white shadow-lg ring-2 ring-white/80 hover:bg-zinc-800"
          style={{ position: "absolute", right: 24, top: "50%", transform: "translateY(-50%)" }}
        >
          <ChevronRight className="h-7 w-7" />
        </button>
      ) : null}
      <img
        src={originalMediaUrl(current) || current}
        alt=""
        className="max-h-[82dvh] max-w-[min(82vw,920px)] object-contain"
        onClick={(e) => e.stopPropagation()}
      />
    </div>,
    document.body
  );
}

export function ChatDayPill({ label }: { label: string }) {
  return (
    <div className="flex justify-center py-1">
      <span className="rounded-full bg-[#22222e] px-3 py-1 text-[11px] font-semibold text-zinc-200 shadow-sm">
        {label}
      </span>
    </div>
  );
}
