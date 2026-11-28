import { config } from "../config";
import { session } from "../session";

export class ApiError extends Error {
  status: number;
  body: unknown;

  constructor(message: string, status: number, body?: unknown) {
    super(message);
    this.status = status;
    this.body = body;
  }
}

async function parseJson(res: Response) {
  const text = await res.text();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

/** Auth endpoints live on the main backend under `/api/x-live/auth/*`. */
export const AUTH_API_PREFIX = "/api/x-live";

async function request<T>(
  base: "auth" | "api",
  path: string,
  options: RequestInit & { auth?: boolean } = {}
): Promise<T> {
  const url = `${config.apiBaseUrl}${base === "auth" ? AUTH_API_PREFIX : ""}${path}`;
  const headers = new Headers(options.headers);
  if (!headers.has("Content-Type") && !(options.body instanceof FormData)) {
    headers.set("Content-Type", "application/json");
  }
  if (options.auth !== false) {
    const jwt = session.getJwt();
    if (jwt) headers.set("Authorization", `Bearer ${jwt}`);
  }
  const res = await fetch(url, { ...options, headers });
  const body = await parseJson(res);
  if (!res.ok) {
    let message = res.statusText || "Request failed";
    if (typeof body === "object" && body !== null) {
      const b = body as Record<string, unknown>;
      const rawMsg = typeof b.message === "string" ? b.message.trim() : "";
      const rawErr = typeof b.error === "string" ? b.error.trim() : "";

      const fieldPartsFrom = (source: Record<string, unknown>) => {
        const fieldParts: string[] = [];
        for (const [k, v] of Object.entries(source)) {
          if (k.toLowerCase() === "message") continue;
          if (typeof v === "string" && v.trim()) {
            fieldParts.push(k ? `${k}: ${v.trim()}` : v.trim());
          } else if (Array.isArray(v)) {
            const msgs = v.filter((x): x is string => typeof x === "string" && x.trim().length > 0);
            if (msgs.length) fieldParts.push(k ? `${k}: ${msgs.join(", ")}` : msgs.join(", "));
          }
        }
        return fieldParts;
      };

      let fieldMessage = "";
      if (b.error && typeof b.error === "object") {
        const errObj = b.error as Record<string, unknown>;
        const parts = fieldPartsFrom(errObj);
        if (parts.length) fieldMessage = parts.slice(0, 3).join(" · ");
        else if (typeof errObj.message === "string" && errObj.message.trim()) {
          fieldMessage = errObj.message.trim();
        } else if (typeof errObj[""] === "string" && errObj[""].trim()) {
          fieldMessage = errObj[""].trim();
        }
      }

      const genericMsg =
        !rawMsg ||
        rawMsg.toLowerCase() === "message" ||
        rawMsg.toLowerCase() === "error" ||
        rawMsg.toLowerCase() === "bad request" ||
        rawMsg.toLowerCase() === "one or more validation errors occurred" ||
        rawMsg.toLowerCase() === "payload validation error" ||
        rawMsg.toLowerCase() === "please check your inputs" ||
        rawMsg.toLowerCase() === "some details look invalid. check your input and try again.";

      if (fieldMessage && genericMsg) {
        message = fieldMessage;
      } else if (rawErr && genericMsg) {
        message = rawErr;
      } else if (rawMsg && !genericMsg) {
        message = rawMsg;
      } else if (rawErr) {
        message = rawErr;
      } else if (fieldMessage) {
        message = fieldMessage;
      }
    }
    throw new ApiError(message, res.status, body);
  }
  return body as T;
}

export const authApi = {
  /** POST to `${apiBaseUrl}/api/x-live${path}`; unauthenticated unless `auth` is true. */
  post<T>(path: string, data: unknown, auth = false) {
    return request<T>("auth", path, { method: "POST", body: JSON.stringify(data), auth });
  },
};

export const api = {
  get<T>(path: string, auth = true) {
    return request<T>("api", path, { method: "GET", auth });
  },
  post<T>(path: string, data?: unknown, auth = true) {
    return request<T>("api", path, {
      method: "POST",
      body: data instanceof FormData ? data : data ? JSON.stringify(data) : undefined,
      auth,
    });
  },
  patch<T>(path: string, data: unknown) {
    return request<T>("api", path, { method: "PATCH", body: JSON.stringify(data) });
  },
  put<T>(path: string, data: unknown) {
    return request<T>("api", path, { method: "PUT", body: JSON.stringify(data) });
  },
  delete<T>(path: string, data?: unknown) {
    return request<T>("api", path, {
      method: "DELETE",
      body: data ? JSON.stringify(data) : undefined,
    });
  },
  upload<T>(path: string, form: FormData) {
    return request<T>("api", path, { method: "POST", body: form });
  },
};

export function withQuery(path: string, params: Record<string, string | number | undefined>) {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([k, v]) => {
    if (v !== undefined && v !== "") search.set(k, String(v));
  });
  const q = search.toString();
  return q ? `${path}?${q}` : path;
}
