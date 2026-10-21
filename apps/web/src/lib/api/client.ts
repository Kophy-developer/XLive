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

async function request<T>(
  base: "auth" | "api",
  path: string,
  options: RequestInit & { auth?: boolean } = {}
): Promise<T> {
  const url = `${base === "auth" ? config.authBaseUrl : config.apiBaseUrl}${path}`;
  const headers = new Headers(options.headers);
  if (!headers.has("Content-Type") && !(options.body instanceof FormData)) {
    headers.set("Content-Type", "application/json");
  }
  if (options.auth !== false && base === "api") {
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

      if (rawErr && (!rawMsg || rawMsg.toLowerCase() === "message" || rawMsg.toLowerCase() === "error" || rawMsg.toLowerCase() === "bad request")) {
        message = rawErr;
      } else if (rawMsg && rawMsg.toLowerCase() !== "message" && rawMsg.toLowerCase() !== "error") {
        message = rawMsg;
      } else if (rawErr) {
        message = rawErr;
      } else if (b.error && typeof b.error === "object") {
        const errObj = b.error as Record<string, unknown>;
        if (typeof errObj.message === "string" && errObj.message.trim()) {
          message = errObj.message.trim();
        } else if (typeof errObj[""] === "string" && errObj[""].trim()) {
          message = errObj[""].trim();
        } else {
          const firstKey = Object.keys(errObj).find((k) => typeof errObj[k] === "string");
          if (firstKey) message = `${firstKey}: ${errObj[firstKey]}`;
        }
      }
    }
    throw new ApiError(message, res.status, body);
  }
  return body as T;
}

export const authApi = {
  post<T>(path: string, data: unknown) {
    return request<T>("auth", path, { method: "POST", body: JSON.stringify(data), auth: false });
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
