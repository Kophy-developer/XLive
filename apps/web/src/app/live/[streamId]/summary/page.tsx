"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { getStream } from "@/lib/api/streams";

export default function StreamSummaryPage() {
  const params = useParams();
  const streamId = params.streamId as string;
  const { data: stream } = useQuery({
    queryKey: ["stream", streamId],
    queryFn: () => getStream(streamId),
  });
  const showReplay = Boolean(stream?.saveEnabled || stream?.hasReplay || stream?.replayUrl);

  return (
    <AuthGuard>
      <PageHeader title="Stream ended" backHref="/live" />
      <div className="mx-auto max-w-md space-y-4 p-6 text-center">
        <p className="text-muted">
          {showReplay
            ? "Your stream has ended. Save a replay or share highlights."
            : "Your stream has ended."}
        </p>
        {showReplay ? (
          <Button asChild className="w-full">
            <Link href={`/live/replay/${streamId}`}>View replay</Link>
          </Button>
        ) : null}
        <Button asChild variant="secondary" className="w-full">
          <Link href="/live">Back to live hub</Link>
        </Button>
      </div>
    </AuthGuard>
  );
}
