"use client";

import { useRef, useState, useEffect } from "react";
import { Upload, Film, Camera, RefreshCw, X, Play } from "lucide-react";
import { cn } from "@/lib/utils";

interface MediaUploadProps {
  files: File[];
  onFilesChange: (files: File[]) => void;
  accept?: string;
  isCollectible?: boolean;
  multiple?: boolean;
  className?: string;
  onEditVideo?: (index: number) => void;
}

function FileThumb({
  file,
  onRemove,
  onEdit,
}: {
  file: File;
  onRemove: () => void;
  onEdit?: () => void;
}) {
  const [preview, setPreview] = useState<string | null>(null);
  const isVideo = file.type.startsWith("video/");

  useEffect(() => {
    const url = URL.createObjectURL(file);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  if (!preview) return null;

  return (
    <div className="relative h-36 w-28 shrink-0 overflow-hidden rounded-2xl border border-white/15 bg-black">
      {isVideo ? (
        <video src={preview} className="h-full w-full object-cover" muted />
      ) : (
        <img src={preview} alt="" className="h-full w-full object-cover" />
      )}
      {isVideo && onEdit ? (
        <button
          type="button"
          onClick={onEdit}
          className="absolute left-1.5 bottom-1.5 rounded-full bg-black/75 px-2 py-0.5 text-[10px] font-semibold text-white"
        >
          Edit
        </button>
      ) : null}
      <button
        type="button"
        onClick={onRemove}
        className="absolute right-1.5 top-1.5 flex h-6 w-6 items-center justify-center rounded-full bg-black/75 text-white hover:bg-red-600"
      >
        <X className="h-3.5 w-3.5" />
      </button>
    </div>
  );
}

export function MediaUpload({
  files,
  onFilesChange,
  accept = "video/*,image/*",
  isCollectible = false,
  multiple = false,
  className,
  onEditVideo,
}: MediaUploadProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [dragOver, setDragOver] = useState(false);
  const [preview, setPreview] = useState<string | null>(null);
  const file = files[0] ?? null;

  useEffect(() => {
    if (!file || (multiple && files.length > 1)) {
      setPreview(null);
      return;
    }
    const url = URL.createObjectURL(file);
    setPreview(url);
    return () => {
      URL.revokeObjectURL(url);
    };
  }, [file, files.length, multiple]);

  const isVideo = Boolean(file?.type.startsWith("video/"));

  function addFiles(list: FileList | File[]) {
    const incoming = Array.from(list);
    if (!incoming.length) return;
    if (!multiple) {
      onFilesChange(incoming.slice(0, 1));
      return;
    }
    onFilesChange([...files, ...incoming]);
  }

  function handleDrop(e: React.DragEvent) {
    e.preventDefault();
    setDragOver(false);
    if (e.dataTransfer.files?.length) addFiles(e.dataTransfer.files);
  }

  if (multiple && files.length > 0) {
    return (
      <div className={cn("relative w-full space-y-3", className)}>
        <input
          ref={inputRef}
          type="file"
          accept={accept}
          multiple
          className="hidden"
          onChange={(e) => {
            if (e.target.files?.length) addFiles(e.target.files);
            e.target.value = "";
          }}
        />
        <div className="flex gap-2 overflow-x-auto pb-1">
          {files.map((item, index) => (
            <FileThumb
              key={`${item.name}-${item.size}-${index}`}
              file={item}
              onRemove={() => onFilesChange(files.filter((_, i) => i !== index))}
              onEdit={item.type.startsWith("video/") && onEditVideo ? () => onEditVideo(index) : undefined}
            />
          ))}
          <button
            type="button"
            onClick={() => inputRef.current?.click()}
            className="flex h-36 w-24 shrink-0 flex-col items-center justify-center rounded-2xl border border-dashed border-white/20 bg-white/5 text-xs font-semibold text-zinc-300 hover:border-brand-purple/50 hover:text-white"
          >
            Add more
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className={cn("relative w-full", className)}>
      <input
        ref={inputRef}
        type="file"
        accept={accept}
        multiple={multiple}
        className="hidden"
        onChange={(e) => {
          if (e.target.files?.length) addFiles(e.target.files);
          e.target.value = "";
        }}
      />

      {preview && file ? (
        <div className="group relative overflow-hidden rounded-3xl border border-white/15 bg-black/80 shadow-2xl transition duration-300">
          {isVideo ? (
            <div className="relative flex items-center justify-center bg-black">
              <video
                src={preview}
                controls
                className="max-h-[380px] w-full object-contain rounded-3xl"
              />
              <div className="pointer-events-none absolute left-4 bottom-4 flex items-center gap-2 rounded-full bg-black/60 px-3 py-1 text-xs font-semibold text-white backdrop-blur-md">
                <Play className="h-3 w-3 fill-white" />
                Video ready
              </div>
            </div>
          ) : (
            <img
              src={preview}
              alt="Media Preview"
              className="max-h-[380px] w-full object-contain rounded-3xl bg-black/50"
            />
          )}

          <div className="absolute top-3 right-3 flex items-center gap-2">
            {isVideo && onEditVideo ? (
              <button
                type="button"
                onClick={() => onEditVideo(0)}
                className="flex items-center gap-1.5 rounded-full bg-black/75 px-3.5 py-1.5 text-xs font-semibold text-white shadow-lg backdrop-blur-md transition hover:bg-black hover:scale-105 active:scale-95"
              >
                Edit
              </button>
            ) : null}
            <button
              type="button"
              onClick={() => inputRef.current?.click()}
              className="flex items-center gap-1.5 rounded-full bg-black/75 px-3.5 py-1.5 text-xs font-semibold text-white shadow-lg backdrop-blur-md transition hover:bg-black hover:scale-105 active:scale-95"
            >
              <RefreshCw className="h-3.5 w-3.5" />
              Change
            </button>
            <button
              type="button"
              onClick={() => {
                onFilesChange([]);
                if (inputRef.current) inputRef.current.value = "";
              }}
              className="flex h-7 w-7 items-center justify-center rounded-full bg-black/75 text-white/80 shadow-lg backdrop-blur-md transition hover:bg-red-600 hover:text-white"
            >
              <X className="h-3.5 w-3.5" />
            </button>
          </div>
        </div>
      ) : (
        <div
          onDragOver={(e) => {
            e.preventDefault();
            setDragOver(true);
          }}
          onDragLeave={() => setDragOver(false)}
          onDrop={handleDrop}
          onClick={() => inputRef.current?.click()}
          className={cn(
            "group flex cursor-pointer flex-col items-center justify-center gap-3 rounded-3xl border-2 border-dashed p-8 text-center transition-all duration-300",
            dragOver
              ? "border-brand-purple bg-brand-purple/10 scale-[0.99]"
              : "border-white/15 bg-[#141420]/80 hover:border-brand-purple/50 hover:bg-[#181827]"
          )}
        >
          <div className="relative flex h-16 w-16 items-center justify-center rounded-2xl brand-gradient text-white shadow-xl shadow-brand-purple/25 transition group-hover:scale-110">
            {isCollectible ? (
              <Film className="h-8 w-8" />
            ) : (
              <Upload className="h-8 w-8" />
            )}
            <div className="absolute inset-0 rounded-2xl bg-white/20 opacity-0 transition group-hover:opacity-100" />
          </div>

          <div>
            <p className="font-display text-sm font-bold text-white tracking-wide">
              {isCollectible
                ? "Upload Collectible Clip Video or Photo"
                : multiple
                ? "Choose photos or videos to post"
                : "Choose a Photo or Video to Post"}
            </p>
            <p className="mt-1 text-xs text-zinc-400">
              {multiple
                ? "Select multiple from your library, or drag and drop"
                : "Drag and drop high quality media here, or browse files"}
            </p>
          </div>

          <div className="mt-1 flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1 text-[11px] font-medium text-zinc-300">
            MP4, MOV, JPG, PNG, WEBP
          </div>
        </div>
      )}
    </div>
  );
}

interface AvatarUploadProps {
  currentAvatarUrl?: string | null;
  onFileSelect: (file: File) => void;
  className?: string;
}

export function AvatarUpload({
  currentAvatarUrl,
  onFileSelect,
  className,
}: AvatarUploadProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [localPreview, setLocalPreview] = useState<string | null>(null);

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (file) {
      setLocalPreview(URL.createObjectURL(file));
      onFileSelect(file);
    }
  }

  const displayUrl = localPreview || currentAvatarUrl;

  return (
    <div className={cn("flex flex-col items-center gap-3", className)}>
      <input
        ref={inputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={handleChange}
      />

      <div
        onClick={() => inputRef.current?.click()}
        className="group relative cursor-pointer"
      >
        <div className="relative flex h-28 w-28 items-center justify-center overflow-hidden rounded-full border-2 border-brand-purple/50 bg-[#161622] p-1 shadow-xl shadow-brand-purple/20 transition group-hover:border-brand-purple group-hover:scale-105">
          {displayUrl ? (
            <img
              src={displayUrl}
              alt="Avatar preview"
              className="h-full w-full rounded-full object-cover"
            />
          ) : (
            <div className="flex h-full w-full items-center justify-center rounded-full brand-gradient text-3xl font-black text-white">
              <Camera className="h-9 w-9 text-white/90" />
            </div>
          )}
          <div className="absolute inset-0 flex items-center justify-center rounded-full bg-black/40 opacity-0 transition group-hover:opacity-100">
            <Camera className="h-8 w-8 text-white drop-shadow-md" />
          </div>
        </div>

        <div className="absolute bottom-0 right-0 flex h-8 w-8 items-center justify-center rounded-full brand-gradient text-white shadow-lg ring-2 ring-[#0c0c12]">
          <Camera className="h-4 w-4" />
        </div>
      </div>

      <div className="text-center">
        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          className="text-xs font-semibold text-brand-purple hover:underline"
        >
          {localPreview ? "Change photo" : "Upload new photo"}
        </button>
        {localPreview ? (
          <p className="mt-0.5 text-[11px] font-medium text-emerald-400">
            Preview updated. Click Save changes below.
          </p>
        ) : null}
      </div>
    </div>
  );
}
