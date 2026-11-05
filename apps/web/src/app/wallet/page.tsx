"use client";

import { useQuery } from "@tanstack/react-query";
import { Suspense, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { getWallet, getTransactions, initiateFund, verifyFund } from "@/lib/api/misc";
import {
  fetchUsdToNgnRate,
  formatWalletMoney,
  ngnToUsd,
  readWalletCurrency,
  writeWalletCurrency,
  type WalletDisplayCurrency,
} from "@/lib/wallet-currency";
import {
  Wallet,
  Coins,
  ArrowUpRight,
  ArrowDownLeft,
  ShieldCheck,
  RefreshCw,
  CreditCard,
  CheckCircle2,
  AlertCircle,
  ExternalLink,
} from "lucide-react";

const coinPacks = [
  { coins: 100, usd: 1 },
  { coins: 300, usd: 3 },
  { coins: 500, usd: 5 },
  { coins: 1000, usd: 10 },
  { coins: 2500, usd: 25 },
  { coins: 5000, usd: 50 },
];

function CurrencySwitcher({
  currency,
  onChange,
  rate,
}: {
  currency: WalletDisplayCurrency;
  onChange: (next: WalletDisplayCurrency) => void;
  rate: number;
}) {
  return (
    <div className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/5 p-1">
      <button
        type="button"
        onClick={() => onChange("NGN")}
        className={`rounded-full px-3 py-1.5 text-[11px] font-bold transition ${
          currency === "NGN" ? "bg-white text-[#1a1a28] shadow-sm" : "text-zinc-300 hover:text-white"
        }`}
        title="Show prices in Nigerian Naira"
      >
        ₦ NGN
      </button>
      <button
        type="button"
        onClick={() => onChange("USD")}
        className={`rounded-full px-3 py-1.5 text-[11px] font-bold transition ${
          currency === "USD" ? "bg-white text-[#1a1a28] shadow-sm" : "text-zinc-300 hover:text-white"
        }`}
        title="Show prices in US Dollars"
      >
        $ USD
      </button>
      <span className="hidden pr-2 text-[10px] font-medium text-zinc-500 sm:inline">
        1 USD ≈ ₦{Math.round(rate).toLocaleString()}
      </span>
    </div>
  );
}

function WalletContent() {
  const searchParams = useSearchParams();
  const [selectedPack, setSelectedPack] = useState(coinPacks[2]);
  const [customAmount, setCustomAmount] = useState("");
  const [provider, setProvider] = useState<"paystack" | "paypal">("paystack");
  const [loading, setLoading] = useState(false);
  const [verifyMessage, setVerifyMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);
  const [currency, setCurrency] = useState<WalletDisplayCurrency>("NGN");
  const [usdToNgn, setUsdToNgn] = useState(1500);

  const { data: wallet, refetch: refetchWallet, isFetching } = useQuery({ queryKey: ["wallet"], queryFn: getWallet });
  const { data: txnsData, refetch: refetchTxns } = useQuery({ queryKey: ["wallet-txns"], queryFn: () => getTransactions() });

  const transactions = txnsData?.transactions ?? [];

  useEffect(() => {
    setCurrency(readWalletCurrency());
    void fetchUsdToNgnRate().then(setUsdToNgn);
  }, []);

  useEffect(() => {
    const paymentId = searchParams.get("paymentId") || searchParams.get("reference") || searchParams.get("trxref");
    if (paymentId) {
      verifyFund({ paymentId, reference: paymentId })
        .then(() => {
          setVerifyMessage({ type: "success", text: "Payment verified successfully. Your balance has been updated." });
          refetchWallet();
          refetchTxns();
        })
        .catch((err) => {
          setVerifyMessage({ type: "error", text: (err as Error).message || "Verification failed" });
        });
    }
  }, [searchParams, refetchWallet, refetchTxns]);

  const amountUsd = useMemo(() => {
    const raw = Number(customAmount);
    if (customAmount && Number.isFinite(raw) && raw > 0) {
      return currency === "NGN" ? ngnToUsd(raw, usdToNgn) : raw;
    }
    return selectedPack.usd;
  }, [customAmount, currency, selectedPack.usd, usdToNgn]);

  const coins = useMemo(() => {
    if (customAmount && Number(customAmount) > 0) return Math.max(1, Math.round(amountUsd * 100));
    return selectedPack.coins;
  }, [amountUsd, customAmount, selectedPack.coins]);

  function onCurrencyChange(next: WalletDisplayCurrency) {
    setCurrency(next);
    writeWalletCurrency(next);
    setCustomAmount("");
  }

  async function handleFund(e: React.FormEvent) {
    e.preventDefault();
    if (!amountUsd || amountUsd <= 0) return;
    setLoading(true);
    setVerifyMessage(null);

    try {
      const res = await initiateFund({
        amount: Number(amountUsd.toFixed(2)),
        provider,
        flow: "redirect",
        coins,
        packageId: String(coins),
      });

      if (res.authorizationUrl) {
        window.location.href = res.authorizationUrl;
      } else {
        refetchWallet();
        refetchTxns();
        setVerifyMessage({ type: "success", text: "Top-up initiated successfully." });
      }
    } catch (err) {
      setVerifyMessage({ type: "error", text: (err as Error).message || "Payment initiation failed" });
    } finally {
      setLoading(false);
    }
  }

  const payLabel = formatWalletMoney(amountUsd, currency, usdToNgn);

  return (
    <AuthGuard>
      <PageHeader
        title="Wallet & Balance"
        backHref="/profile/me"
        action={
          <div className="flex items-center gap-2">
            <CurrencySwitcher currency={currency} onChange={onCurrencyChange} rate={usdToNgn} />
            <Button
              variant="ghost"
              size="sm"
              onClick={() => refetchWallet()}
              disabled={isFetching}
              className="gap-1.5 rounded-xl text-xs text-muted hover:text-foreground"
            >
              <RefreshCw className={`h-3.5 w-3.5 ${isFetching ? "animate-spin" : ""}`} />
              Refresh
            </Button>
          </div>
        }
      />

      <div className="mx-auto max-w-2xl space-y-6 p-4 sm:p-6">
        {verifyMessage && (
          <div
            className={`flex items-center gap-3 rounded-2xl border p-4 text-xs font-semibold backdrop-blur-xl ${
              verifyMessage.type === "success"
                ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-400"
                : "border-red-500/30 bg-red-500/10 text-red-400"
            }`}
          >
            {verifyMessage.type === "success" ? (
              <CheckCircle2 className="h-5 w-5 shrink-0" />
            ) : (
              <AlertCircle className="h-5 w-5 shrink-0" />
            )}
            <p className="flex-1">{verifyMessage.text}</p>
          </div>
        )}

        <div className="relative overflow-hidden rounded-3xl brand-gradient p-6 text-white shadow-xl shadow-brand-purple/20 sm:p-8">
          <div className="absolute right-4 top-4 opacity-15">
            <Coins className="h-32 w-32" />
          </div>

          <div className="relative z-10">
            <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-white/80">
              <Wallet className="h-4 w-4" />
              <span>Available Coin Balance</span>
            </div>

            <p className="mt-3 font-sans text-4xl font-bold tracking-tight tabular-nums sm:text-5xl">
              {(wallet?.balance ?? 0).toLocaleString()} <span className="text-xl font-medium text-white/80">coins</span>
            </p>

            <p className="mt-2 flex items-center gap-1.5 text-xs text-white/80">
              <ShieldCheck className="h-4 w-4" />
              Instant deductions for paid private lives, clips & gifts
            </p>
          </div>
        </div>

        <div className="space-y-5 rounded-3xl border border-white/10 bg-[#141420]/80 p-6 shadow-xl backdrop-blur-xl">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 className="font-sans text-base font-bold tracking-tight text-white">Top up Coins</h2>
              <p className="mt-1 text-xs text-zinc-400">
                Prices shown in {currency === "NGN" ? "Naira" : "US Dollars"}. Checkout still charges via your selected provider.
              </p>
            </div>
            <CurrencySwitcher currency={currency} onChange={onCurrencyChange} rate={usdToNgn} />
          </div>

          <div className="space-y-2">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">Select Coin Package</label>
            <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3">
              {coinPacks.map((pack) => {
                const isSelected = !customAmount && selectedPack.coins === pack.coins;
                return (
                  <button
                    key={pack.coins}
                    type="button"
                    onClick={() => {
                      setSelectedPack(pack);
                      setCustomAmount("");
                    }}
                    className={`flex flex-col items-center justify-center rounded-2xl border p-3.5 text-center transition-all ${
                      isSelected
                        ? "border-brand-purple bg-brand-purple/20 text-white shadow-md shadow-brand-purple/20"
                        : "border-white/10 bg-white/5 text-zinc-300 hover:bg-white/10"
                    }`}
                  >
                    <div className="flex items-center gap-1.5 text-base font-bold tabular-nums">
                      <Coins className="h-4 w-4 text-amber-400" />
                      <span>{pack.coins.toLocaleString()}</span>
                    </div>
                    <span className="mt-1 text-xs font-semibold text-zinc-200">
                      {formatWalletMoney(pack.usd, currency, usdToNgn)}
                    </span>
                    <span className="text-[10px] text-zinc-500">
                      {currency === "NGN"
                        ? formatWalletMoney(pack.usd, "USD", usdToNgn)
                        : formatWalletMoney(pack.usd, "NGN", usdToNgn)}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Or Custom Amount ({currency})
            </label>
            <div className="relative">
              <Input
                type="number"
                placeholder={currency === "NGN" ? "Enter Naira amount (e.g. 7500)" : "Enter USD amount (e.g. 15)"}
                value={customAmount}
                onChange={(e) => setCustomAmount(e.target.value)}
                min={1}
                className="h-11 rounded-2xl border-white/10 bg-[#161622] pl-4"
              />
              {customAmount && Number(customAmount) > 0 && (
                <div className="absolute right-4 top-3 text-xs font-bold tabular-nums text-brand-purple">
                  ≈ {coins.toLocaleString()} coins
                </div>
              )}
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">Payment Method</label>
            <div className="grid grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setProvider("paystack")}
                className={`flex items-center gap-3 rounded-2xl border p-3.5 text-left transition ${
                  provider === "paystack"
                    ? "border-brand-purple bg-brand-purple/20 text-white"
                    : "border-white/10 bg-white/5 text-zinc-300 hover:bg-white/10"
                }`}
              >
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-white/10 text-brand-purple">
                  <CreditCard className="h-5 w-5" />
                </div>
                <div>
                  <p className="font-sans text-xs font-bold text-white">Paystack</p>
                  <p className="text-[10px] text-zinc-400">Debit card, Bank, USSD</p>
                </div>
              </button>

              <button
                type="button"
                onClick={() => setProvider("paypal")}
                className={`flex items-center gap-3 rounded-2xl border p-3.5 text-left transition ${
                  provider === "paypal"
                    ? "border-brand-purple bg-brand-purple/20 text-white"
                    : "border-white/10 bg-white/5 text-zinc-300 hover:bg-white/10"
                }`}
              >
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-white/10 text-sky-400">
                  <ExternalLink className="h-5 w-5" />
                </div>
                <div>
                  <p className="font-sans text-xs font-bold text-white">PayPal</p>
                  <p className="text-[10px] text-zinc-400">Card, PayPal Balance</p>
                </div>
              </button>
            </div>
          </div>

          <form onSubmit={handleFund}>
            <Button
              type="submit"
              disabled={loading || amountUsd <= 0}
              className="h-12 w-full rounded-2xl brand-gradient font-bold text-white shadow-xl shadow-brand-purple/25 transition hover:opacity-95 active:scale-[0.99]"
            >
              {loading ? (
                <span className="flex items-center gap-2">
                  <RefreshCw className="h-4 w-4 animate-spin" /> Connecting to {provider === "paystack" ? "Paystack" : "PayPal"}…
                </span>
              ) : (
                `Pay ${payLabel} with ${provider === "paystack" ? "Paystack" : "PayPal"}`
              )}
            </Button>
          </form>
        </div>

        <div className="rounded-3xl border border-white/10 bg-[#141420]/80 p-6 shadow-xl backdrop-blur-xl">
          <h2 className="font-sans text-base font-bold tracking-tight text-white">Recent Transactions</h2>

          {transactions.length === 0 ? (
            <p className="py-8 text-center text-xs text-zinc-400">No transactions recorded yet</p>
          ) : (
            <div className="mt-4 divide-y divide-white/10">
              {transactions.map((tx, idx) => {
                const type = String(tx.type ?? tx.action ?? "credit");
                const isCredit = type.includes("credit") || type.includes("fund") || type.includes("deposit");
                const amountVal = Number(tx.amount ?? tx.coins ?? 0);
                const desc = String(tx.description ?? tx.reason ?? (isCredit ? "Wallet Top up" : "Payment"));
                const date = tx.createdAt ? new Date(String(tx.createdAt)).toLocaleDateString() : "";

                return (
                  <div key={idx} className="flex items-center justify-between py-3">
                    <div className="flex items-center gap-3">
                      <div
                        className={`flex h-9 w-9 items-center justify-center rounded-xl ${
                          isCredit ? "bg-emerald-500/15 text-emerald-500" : "bg-red-500/15 text-red-500"
                        }`}
                      >
                        {isCredit ? <ArrowDownLeft className="h-4 w-4" /> : <ArrowUpRight className="h-4 w-4" />}
                      </div>
                      <div>
                        <p className="text-sm font-semibold text-white">{desc}</p>
                        <p className="text-[11px] text-zinc-400">{date}</p>
                      </div>
                    </div>
                    <span className={`text-sm font-bold tabular-nums ${isCredit ? "text-emerald-500" : "text-white"}`}>
                      {isCredit ? "+" : "-"}
                      {amountVal.toLocaleString()} coins
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </AuthGuard>
  );
}

export default function WalletPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-background" />}>
      <WalletContent />
    </Suspense>
  );
}
