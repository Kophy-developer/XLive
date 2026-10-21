"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { X, Scissors, Ratio, Music, Loader2, Play } from "lucide-react";
import { Button } from "@/components/ui/button";

type Aspect = "original" | "9:16" | "1:1" | "16:9";

function even(n: number) {
  const v = Math.max(2, Math.floor(n));
  return v % 2 === 0 ? v : v - 1;
}

function cropRect(vw: number, vh: number, aspect: Aspect) {
  if (aspect === "original" || vw <= 0 || vh <= 0) {
    return { sx: 0, sy: 0, sw: vw, sh: vh };
  }
  const [aw, ah] = aspect === "9:16" ? [9, 16] : aspect === "1:1" ? [1, 1] : [16, 9];
  let w: number;
  let h: number;
  if (vw / vh > aw / ah) {
    h = vh;
    w = (vh * aw) / ah;
  } else {
    w = vw;
    h = (vw * ah) / aw;
  }
  w = even(w);
  h = even(h);
  const x = even((vw - w) / 2);
  const y = even((vh - h) / 2);
  return { sx: x, sy: y, sw: w, sh: h };
}

function formatTime(seconds: number) {
  if (!Number.isFinite(seconds) || seconds < 0) return "0:00";
  const m = Math.floor(seconds);
  const s = Math.floor(seconds % 60);
  return `${Math.floor(m / 60)}:${s.toString().padStart(2, "0")}`;
}

function pickRecorderMime() {
  const types = [
    "video/webm;codecs=vp9,opus",
    "video/webm;codecs=vp8,opus",
    "video/webm",
    "video/mp4;codecs=avc1.42E01E,mp4a.40.2",
    "video/mp4",
  ];
  for (const type of types) {
    if (typeof MediaRecorder !== "undefined" && MediaRecorder.isTypeSupported(type)) return type;
  }
  return "";
}

function waitEvent(el: HTMLMediaElement, event: string) {
  return new Promise<void>((resolve, reject) => {
    const onOk = () => {
      el.removeEventListener(event, onOk);
      el.removeEventListener("error", onErr);
      resolve();
    };
    const onErr = () => {
      el.removeEventListener(event, onOk);
      el.removeEventListener("error", onErr);
      reject(new Error("Could not load media for export"));
    };
    el.addEventListener(event, onOk);
    el.addEventListener("error", onErr);
  });
}

const AUDIO_EXTS = [".mp3", ".m4a", ".wav", ".aac", ".ogg", ".wma", ".flac"];

export function VideoEditor({
  file,
  onCancel,
  onApply,
}: {
  file: File;
  onCancel: () => void;
  onApply: (next: File, durationSeconds: number) => void;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const audioRef = useRef<HTMLAudioElement>(null);
  const audioInputRef = useRef<HTMLInputElement>(null);
  const trackRef = useRef<HTMLDivElement>(null);
  const dragRef = useRef<"start" | "end" | null>(null);
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState("");
  const [duration, setDuration] = useState(0);
  const [size, setSize] = useState({ w: 0, h: 0 });
  const [start, setStart] = useState(0);
  const [end, setEnd] = useState(0);
  const [playhead, setPlayhead] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [aspect, setAspect] = useState<Aspect>("original");
  const [mute, setMute] = useState(false);
  const [music, setMusic] = useState<File | null>(null);
  const [mounted, setMounted] = useState(false);
  const previewUrl = useMemo(() => URL.createObjectURL(file), [file]);
  const musicUrl = useMemo(() => (music ? URL.createObjectURL(music) : null), [music]);
  const ready = duration > 0 && size.w > 0;

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    return () => URL.revokeObjectURL(previewUrl);
  }, [previewUrl]);

  useEffect(() => {
    return () => {
      if (musicUrl) URL.revokeObjectURL(musicUrl);
    };
  }, [musicUrl]);

  const seekVideo = useCallback((time: number) => {
    const el = videoRef.current;
    if (!el) return;
    el.currentTime = Math.min(Math.max(time, 0), duration || el.duration || 0);
  }, [duration]);

  const syncAudio = useCallback(() => {
    const video = videoRef.current;
    const audio = audioRef.current;
    if (!video || !audio || !musicUrl) return;
    const rel = Math.max(0, video.currentTime - start);
    if (Math.abs(audio.currentTime - rel) > 0.25) audio.currentTime = rel;
  }, [musicUrl, start]);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    video.muted = mute || Boolean(musicUrl);
  }, [mute, musicUrl]);

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;
    if (!musicUrl) {
      audio.pause();
      return;
    }
    if (playing) {
      syncAudio();
      audio.play().catch(() => {});
    } else {
      audio.pause();
    }
  }, [musicUrl, playing, syncAudio]);

  function onMeta() {
    const el = videoRef.current;
    if (!el) return;
    const d = Number.isFinite(el.duration) ? el.duration : 0;
    setDuration(d);
    setStart(0);
    setEnd(d);
    setPlayhead(0);
    setSize({ w: el.videoWidth || 0, h: el.videoHeight || 0 });
  }

  function togglePlay() {
    const video = videoRef.current;
    if (!video || duration <= 0) return;
    if (playing) {
      video.pause();
      audioRef.current?.pause();
      setPlaying(false);
      return;
    }
    if (video.currentTime < start || video.currentTime >= end - 0.05) {
      video.currentTime = start;
    }
    video.muted = mute || Boolean(musicUrl);
    video.play().then(() => {
      setPlaying(true);
      if (musicUrl && audioRef.current) {
        audioRef.current.currentTime = Math.max(0, video.currentTime - start);
        audioRef.current.play().catch(() => {});
      }
    }).catch(() => setPlaying(false));
  }

  function onTimeUpdate() {
    const video = videoRef.current;
    if (!video) return;
    setPlayhead(video.currentTime);
    if (video.currentTime >= end - 0.04) {
      video.pause();
      video.currentTime = start;
      audioRef.current?.pause();
      setPlaying(false);
      setPlayhead(start);
      return;
    }
    syncAudio();
  }

  function timeFromPointer(clientX: number) {
    const track = trackRef.current;
    if (!track || duration <= 0) return 0;
    const rect = track.getBoundingClientRect();
    const p = Math.min(1, Math.max(0, (clientX - rect.left) / rect.width));
    return p * duration;
  }

  function onTrackPointerDown(e: React.PointerEvent, which: "start" | "end") {
    dragRef.current = which;
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    const t = timeFromPointer(e.clientX);
    if (which === "start") {
      const next = Math.min(t, end - 0.2);
      setStart(next);
      seekVideo(next);
      setPlayhead(next);
    } else {
      const next = Math.max(t, start + 0.2);
      setEnd(next);
      seekVideo(next);
      setPlayhead(next);
    }
  }

  function onTrackPointerMove(e: React.PointerEvent) {
    if (!dragRef.current) return;
    const t = timeFromPointer(e.clientX);
    if (dragRef.current === "start") {
      const next = Math.min(Math.max(0, t), end - 0.2);
      setStart(next);
      seekVideo(next);
      setPlayhead(next);
    } else {
      const next = Math.max(Math.min(duration, t), start + 0.2);
      setEnd(next);
      seekVideo(next);
      setPlayhead(next);
    }
  }

  function onTrackPointerUp() {
    dragRef.current = null;
  }

  function onMusicPicked(picked: File | null) {
    if (!picked) {
      setMusic(null);
      return;
    }
    const name = picked.name.toLowerCase();
    const ok = AUDIO_EXTS.some((ext) => name.endsWith(ext));
    if (!ok || picked.type.startsWith("video/")) {
      setError("Choose an audio file (MP3, M4A, WAV, AAC, OGG, WMA, FLAC).");
      if (audioInputRef.current) audioInputRef.current.value = "";
      return;
    }
    setError("");
    setMusic(picked);
  }

  async function apply() {
    if (!ready || busy) return;
    const clip = Math.max(0.2, end - start);
    const mime = pickRecorderMime();
    if (!mime) {
      setError("This browser cannot export video. Try Chrome or Edge.");
      return;
    }
    videoRef.current?.pause();
    audioRef.current?.pause();
    setPlaying(false);
    setBusy(true);
    setError("");
    setProgress(0);

    const exportVideo = document.createElement("video");
    exportVideo.src = previewUrl;
    exportVideo.playsInline = true;
    exportVideo.muted = true;
    exportVideo.preload = "auto";
    const exportAudio = document.createElement("audio");
    let audioCtx: AudioContext | null = null;
    const stopTracks: MediaStreamTrack[] = [];

    try {
      exportVideo.load();
      if (exportVideo.readyState < 1) await waitEvent(exportVideo, "loadedmetadata");
      const vw = exportVideo.videoWidth || size.w;
      const vh = exportVideo.videoHeight || size.h;
      const { sx, sy, sw, sh } = cropRect(vw, vh, aspect);
      const scale = Math.min(1, 1080 / Math.max(sw, sh, 1));
      const outW = even(Math.max(2, Math.round(sw * scale)));
      const outH = even(Math.max(2, Math.round(sh * scale)));
      const canvas = document.createElement("canvas");
      canvas.width = outW;
      canvas.height = outH;
      const ctx = canvas.getContext("2d");
      if (!ctx) throw new Error("Could not export this video");

      if (Math.abs(exportVideo.currentTime - start) > 0.05) {
        await new Promise<void>((resolve, reject) => {
          let settled = false;
          const timer = window.setTimeout(() => {
            if (settled) return;
            settled = true;
            exportVideo.removeEventListener("seeked", done);
            reject(new Error("Could not seek this video"));
          }, 8000);
          const done = () => {
            if (settled) return;
            settled = true;
            window.clearTimeout(timer);
            exportVideo.removeEventListener("seeked", done);
            resolve();
          };
          exportVideo.addEventListener("seeked", done);
          exportVideo.currentTime = start;
        });
      } else {
        exportVideo.currentTime = start;
      }

      ctx.drawImage(exportVideo, sx, sy, sw, sh, 0, 0, outW, outH);
      const canvasStream = canvas.captureStream(30);
      canvasStream.getTracks().forEach((t) => stopTracks.push(t));

      const mixed = new MediaStream();
      canvasStream.getVideoTracks().forEach((t) => mixed.addTrack(t));

      audioCtx = new AudioContext();
      await audioCtx.resume().catch(() => {});
      const dest = audioCtx.createMediaStreamDestination();
      if (musicUrl) {
        exportAudio.src = musicUrl;
        exportAudio.preload = "auto";
        exportAudio.load();
        if (exportAudio.readyState < 1) await waitEvent(exportAudio, "loadedmetadata");
        const musicNode = audioCtx.createMediaElementSource(exportAudio);
        musicNode.connect(dest);
        dest.stream.getAudioTracks().forEach((t) => {
          mixed.addTrack(t);
          stopTracks.push(t);
        });
      } else if (!mute) {
        exportVideo.muted = false;
        exportVideo.volume = 1;
        const videoNode = audioCtx.createMediaElementSource(exportVideo);
        videoNode.connect(dest);
        dest.stream.getAudioTracks().forEach((t) => {
          mixed.addTrack(t);
          stopTracks.push(t);
        });
      }

      const chunks: Blob[] = [];
      const recorder = new MediaRecorder(mixed, { mimeType: mime, videoBitsPerSecond: 3_500_000 });
      recorder.ondataavailable = (e) => {
        if (e.data && e.data.size > 0) chunks.push(e.data);
      };
      const stopped = new Promise<void>((resolve) => {
        recorder.onstop = () => resolve();
      });
      recorder.start(200);
      exportVideo.currentTime = start;
      await exportVideo.play();
      if (musicUrl) {
        exportAudio.currentTime = 0;
        await exportAudio.play().catch(() => {});
      }

      await new Promise<void>((resolve) => {
        let finished = false;
        const finish = () => {
          if (finished) return;
          finished = true;
          resolve();
        };
        const tick = () => {
          if (finished) return;
          const t = exportVideo.currentTime;
          ctx.drawImage(exportVideo, sx, sy, sw, sh, 0, 0, outW, outH);
          const pct = Math.max(0, Math.min(99, Math.round(((t - start) / clip) * 100)));
          setProgress(pct);
          if (t >= end - 0.05 || exportVideo.ended) {
            finish();
            return;
          }
          requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
        window.setTimeout(finish, (clip + 2) * 1000);
      });

      if (recorder.state !== "inactive") recorder.stop();
      await stopped;
      exportVideo.pause();
      exportAudio.pause();
      const container = mime.split(";")[0] || "video/webm";
      const blob = new Blob(chunks, { type: container });
      if (blob.size < 32) throw new Error("Export produced an empty file");
      const ext = container.includes("mp4") ? "mp4" : "webm";
      onApply(
        new File([blob], file.name.replace(/\.[^.]+$/, "") + `-edited.${ext}`, { type: container }),
        Math.max(1, Math.round(clip))
      );
    } catch (err) {
      setError((err as Error).message || "Edit failed");
    } finally {
      exportVideo.pause();
      exportVideo.removeAttribute("src");
      exportVideo.load();
      exportAudio.pause();
      exportAudio.removeAttribute("src");
      stopTracks.forEach((t) => t.stop());
      if (audioCtx) await audioCtx.close().catch(() => {});
      setBusy(false);
      setProgress(0);
    }
  }

  const startPct = duration > 0 ? (start / duration) * 100 : 0;
  const endPct = duration > 0 ? (end / duration) * 100 : 100;
  const headPct = duration > 0 ? (playhead / duration) * 100 : 0;

  const body = (
    <div className="fixed inset-0 z-[200] flex flex-col bg-[#07070c] text-white">
      <header className="flex h-14 shrink-0 items-center justify-between border-b border-white/10 px-4 md:px-6">
        <p className="font-display text-sm font-bold">Edit video</p>
        <button type="button" onClick={onCancel} className="rounded-full p-2 text-zinc-400 hover:bg-white/10 hover:text-white">
          <X className="h-5 w-5" />
        </button>
      </header>

      <div className="relative flex min-h-0 flex-1 items-center justify-center bg-black px-3 py-3">
        <div
          className={`relative h-full max-h-full overflow-hidden rounded-2xl bg-black ${
            aspect === "9:16"
              ? "aspect-[9/16] max-w-[min(100%,420px)]"
              : aspect === "1:1"
              ? "aspect-square max-w-[min(100%,560px)]"
              : aspect === "16:9"
              ? "aspect-video w-full max-w-5xl"
              : "w-full max-w-5xl"
          }`}
        >
          <video
            ref={videoRef}
            src={previewUrl}
            playsInline
            onLoadedMetadata={onMeta}
            onTimeUpdate={onTimeUpdate}
            onPause={() => setPlaying(false)}
            onPlay={() => setPlaying(true)}
            className={`h-full w-full ${aspect === "original" ? "object-contain" : "object-cover"}`}
          />
          {!playing ? (
            <button
              type="button"
              onClick={togglePlay}
              className="absolute inset-0 z-10 flex items-center justify-center bg-black/45"
              aria-label="Play"
            >
              <span className="flex h-16 w-16 items-center justify-center rounded-full bg-white/90 text-black shadow-xl">
                <Play className="h-7 w-7 fill-black pl-0.5" />
              </span>
            </button>
          ) : (
            <button type="button" onClick={togglePlay} className="absolute inset-0 z-10" aria-label="Pause" />
          )}
        </div>
      </div>

      {musicUrl ? <audio ref={audioRef} src={musicUrl} preload="auto" /> : null}

      <div className="shrink-0 space-y-4 border-t border-white/10 bg-[#101018] px-4 py-4 md:px-8">
        <div className="space-y-2">
          <div className="flex items-center justify-between text-[11px] font-bold uppercase tracking-wider text-zinc-400">
            <span className="flex items-center gap-2">
              <Scissors className="h-3.5 w-3.5" /> Trim
            </span>
            <span className="normal-case font-semibold text-zinc-300">
              {formatTime(start)} – {formatTime(end)}
            </span>
          </div>
          <div
            ref={trackRef}
            className="relative h-10 select-none rounded-full bg-white/10"
            onPointerMove={onTrackPointerMove}
            onPointerUp={onTrackPointerUp}
            onPointerCancel={onTrackPointerUp}
          >
            <div
              className="absolute inset-y-0 rounded-full bg-brand-purple/50"
              style={{ left: `${startPct}%`, width: `${Math.max(2, endPct - startPct)}%` }}
            />
            <div
              className="absolute top-0 z-10 h-full w-0.5 bg-white"
              style={{ left: `${headPct}%` }}
            />
            <button
              type="button"
              className="absolute top-1/2 z-20 h-10 w-4 -translate-x-1/2 -translate-y-1/2 rounded-full bg-white shadow"
              style={{ left: `${startPct}%` }}
              onPointerDown={(e) => onTrackPointerDown(e, "start")}
              onPointerMove={onTrackPointerMove}
              onPointerUp={onTrackPointerUp}
              onPointerCancel={onTrackPointerUp}
              aria-label="Trim start"
            />
            <button
              type="button"
              className="absolute top-1/2 z-20 h-10 w-4 -translate-x-1/2 -translate-y-1/2 rounded-full bg-white shadow"
              style={{ left: `${endPct}%` }}
              onPointerDown={(e) => onTrackPointerDown(e, "end")}
              onPointerMove={onTrackPointerMove}
              onPointerUp={onTrackPointerUp}
              onPointerCancel={onTrackPointerUp}
              aria-label="Trim end"
            />
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <span className="flex items-center gap-2 text-[11px] font-bold uppercase tracking-wider text-zinc-400">
            <Ratio className="h-3.5 w-3.5" /> Crop
          </span>
          {(["original", "9:16", "1:1", "16:9"] as Aspect[]).map((item) => (
            <button
              key={item}
              type="button"
              onClick={() => setAspect(item)}
              className={`rounded-full px-3 py-1.5 text-xs font-semibold ${
                aspect === item ? "brand-gradient text-white" : "border border-white/10 bg-white/5 text-zinc-300"
              }`}
            >
              {item === "original" ? "Original" : item}
            </button>
          ))}
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <span className="flex items-center gap-2 text-[11px] font-bold uppercase tracking-wider text-zinc-400">
            <Music className="h-3.5 w-3.5" /> Audio
          </span>
          <label className="flex items-center gap-2 text-xs font-semibold text-white">
            <input type="checkbox" checked={mute} onChange={(e) => setMute(e.target.checked)} className="accent-brand-purple" />
            Mute original sound
          </label>
          <input
            ref={audioInputRef}
            type="file"
            accept=".mp3,.m4a,.wav,.aac,.ogg,.wma,.flac,audio/mpeg,audio/mp4,audio/wav,audio/aac,audio/ogg,audio/flac"
            className="hidden"
            onChange={(e) => onMusicPicked(e.target.files?.[0] ?? null)}
          />
          <button
            type="button"
            onClick={() => audioInputRef.current?.click()}
            className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-xs font-semibold text-zinc-200 hover:bg-white/10"
          >
            {music ? music.name : "Add audio (MP3, M4A, WAV)"}
          </button>
          {music ? (
            <button type="button" onClick={() => setMusic(null)} className="text-xs text-red-400">
              Remove
            </button>
          ) : null}
        </div>

        {error ? <p className="text-xs font-semibold text-red-400">{error}</p> : null}
        {busy ? (
          <p className="text-xs font-semibold text-zinc-300">Applying edits… {progress}%</p>
        ) : null}

        <div className="flex gap-3 pt-1">
          <button
            type="button"
            onClick={onCancel}
            className="h-12 flex-1 rounded-2xl border border-white/10 text-xs font-bold text-zinc-300 hover:bg-white/5"
          >
            Cancel
          </button>
          <Button
            type="button"
            onClick={apply}
            disabled={!ready || busy || duration <= 0}
            className="h-12 flex-1 rounded-2xl brand-gradient text-xs font-bold text-white disabled:opacity-40"
          >
            {busy ? (
              <span className="flex items-center gap-2">
                <Loader2 className="h-4 w-4 animate-spin" />
                Applying
              </span>
            ) : (
              "Apply edits"
            )}
          </Button>
        </div>
      </div>
    </div>
  );

  if (!mounted) return null;
  return createPortal(body, document.body);
}
