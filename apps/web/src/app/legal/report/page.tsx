"use client";

import { useEffect, useState } from "react";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { Input, Textarea } from "@/components/ui/input";
import { api } from "@/lib/api/client";

export default function ReportPage() {
  const [targetType, setTargetType] = useState("user");
  const [targetId, setTargetId] = useState("");
  const [reason, setReason] = useState("");
  const [sent, setSent] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const q = new URLSearchParams(window.location.search);
    const type = q.get("targetType");
    const id = q.get("targetId");
    if (type) setTargetType(type);
    if (id) setTargetId(id);
  }, []);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    try {
      await api.post("/api/x-live/legal/report", { targetType, targetId, reason });
      setSent(true);
    } catch (err) {
      setError((err as Error).message || "Report failed");
    }
  }

  return (
    <AuthGuard>
      <PageHeader title="Report" backHref="/profile/settings" />
      {sent ? (
        <p className="p-6 text-muted">Report submitted. Our team will review it.</p>
      ) : (
        <form onSubmit={handleSubmit} className="mx-auto max-w-md space-y-4 p-6">
          <Input placeholder="Target ID" value={targetId} onChange={(e) => setTargetId(e.target.value)} required />
          <select
            value={targetType}
            onChange={(e) => setTargetType(e.target.value)}
            className="h-11 w-full rounded-xl border border-border bg-surface px-4 text-sm"
          >
            <option value="user">User</option>
            <option value="content">Content</option>
            <option value="group">Group</option>
          </select>
          <Textarea placeholder="Reason" value={reason} onChange={(e) => setReason(e.target.value)} required />
          {error ? <p className="text-sm text-red-500">{error}</p> : null}
          <Button type="submit" className="w-full">Submit report</Button>
        </form>
      )}
    </AuthGuard>
  );
}
