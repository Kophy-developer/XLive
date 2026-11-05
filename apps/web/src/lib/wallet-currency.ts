export type WalletDisplayCurrency = "NGN" | "USD";

const STORAGE_KEY = "xlive_wallet_display_currency";
const FALLBACK_USD_NGN = 1500;

let cachedRate: { usdToNgn: number; fetchedAt: number } | null = null;

export function readWalletCurrency(): WalletDisplayCurrency {
  if (typeof window === "undefined") return "NGN";
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw === "USD" || raw === "NGN") return raw;
  } catch {
  }
  return "NGN";
}

export function writeWalletCurrency(currency: WalletDisplayCurrency) {
  if (typeof window === "undefined") return;
  try {
    localStorage.setItem(STORAGE_KEY, currency);
  } catch {
  }
}

export async function fetchUsdToNgnRate(): Promise<number> {
  const now = Date.now();
  if (cachedRate && now - cachedRate.fetchedAt < 30 * 60 * 1000) {
    return cachedRate.usdToNgn;
  }

  const endpoints = [
    "https://open.er-api.com/v6/latest/USD",
    "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.min.json",
  ];

  for (const url of endpoints) {
    try {
      const res = await fetch(url, { cache: "no-store" });
      if (!res.ok) continue;
      const json = (await res.json()) as Record<string, unknown>;
      let rate = 0;
      if (json.rates && typeof json.rates === "object") {
        rate = Number((json.rates as Record<string, unknown>).NGN);
      } else if (json.usd && typeof json.usd === "object") {
        rate = Number((json.usd as Record<string, unknown>).ngn);
      }
      if (Number.isFinite(rate) && rate > 100) {
        cachedRate = { usdToNgn: rate, fetchedAt: now };
        return rate;
      }
    } catch {
    }
  }

  if (cachedRate) return cachedRate.usdToNgn;
  cachedRate = { usdToNgn: FALLBACK_USD_NGN, fetchedAt: now };
  return FALLBACK_USD_NGN;
}

export function formatWalletMoney(amountUsd: number, currency: WalletDisplayCurrency, usdToNgn: number) {
  if (currency === "USD") {
    return `$${amountUsd.toLocaleString(undefined, { minimumFractionDigits: amountUsd % 1 === 0 ? 0 : 2, maximumFractionDigits: 2 })}`;
  }
  const naira = Math.round(amountUsd * usdToNgn);
  return `₦${naira.toLocaleString()}`;
}

export function ngnToUsd(amountNgn: number, usdToNgn: number) {
  if (!usdToNgn || usdToNgn <= 0) return 0;
  return amountNgn / usdToNgn;
}
