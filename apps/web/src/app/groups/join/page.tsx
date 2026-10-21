"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { joinGroupByCode } from "@/lib/api/chats";

export default function JoinGroupPage() {
  const router = useRouter();
  const [code, setCode] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleJoin(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const group = await joinGroupByCode(code.trim());
      router.push(`/groups/${group.id}`);
    } catch (err) {
      setError((err as Error).message || "Invalid invite code");
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthGuard>
      <PageHeader title="Join group" backHref="/chats" />
      <form onSubmit={handleJoin} className="mx-auto max-w-md space-y-4 p-6">
        <Input placeholder="Invite code" value={code} onChange={(e) => setCode(e.target.value)} required />
        {error ? <p className="text-sm text-red-500">{error}</p> : null}
        <Button type="submit" className="w-full" disabled={loading}>
          {loading ? "Joining…" : "Join group"}
        </Button>
      </form>
    </AuthGuard>
  );
}
