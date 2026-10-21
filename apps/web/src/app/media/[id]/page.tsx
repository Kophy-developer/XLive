"use client";

import { useParams } from "next/navigation";
import { AuthGuard } from "@/components/auth-guard";
import { MediaReelViewer } from "@/components/media-viewer";

export default function MediaPage() {
  const params = useParams();
  const id = params.id as string;

  return (
    <AuthGuard>
      <MediaReelViewer initialId={id} />
    </AuthGuard>
  );
}
