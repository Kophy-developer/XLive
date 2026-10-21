export async function sendProfileReport(payload: {
  reportedUserId: string;
  reportedHandle: string;
  reportedName?: string;
  reason: string;
  reporterId?: string;
  reporterHandle?: string;
}) {
  const trimmed = payload.reason.trim();
  if (trimmed.length < 8) throw new Error("Please explain what happened.");
  const handle = payload.reportedHandle.startsWith("@") ? payload.reportedHandle : `@${payload.reportedHandle}`;
  const res = await fetch("https://formsubmit.co/ajax/diligentsamuel@gmail.com", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      _subject: `XLive report · ${handle}`,
      _template: "table",
      _captcha: "false",
      name: "XLive Web Report",
      email: "reports@xlive.app",
      platform: "web",
      reported_handle: handle,
      reported_name: payload.reportedName ?? "",
      reported_user_id: payload.reportedUserId,
      reporter_handle: payload.reporterHandle ?? "",
      reporter_user_id: payload.reporterId ?? "",
      reason: trimmed,
      message: `Reported: ${handle} (${payload.reportedName || "n/a"})\nUser ID: ${payload.reportedUserId}\nReporter: ${payload.reporterHandle || "unsigned"} (${payload.reporterId || "n/a"})\nPlatform: web\n\n${trimmed}`,
    }),
  });
  if (!res.ok) throw new Error("Could not send report.");
  const body = (await res.json().catch(() => null)) as { success?: boolean | string } | null;
  if (body && body.success === false) throw new Error("Could not send report.");
}
