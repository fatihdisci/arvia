import { Redis } from "@upstash/redis";

// Vercel Edge runtime — stateless, no filesystem, Web Crypto available.
export const config = { runtime: "edge" };

// ─────────────────────────────────────────────────────────────────────────────
// Model is a single const so switching to Gemini later = one edit + one adapter.
const DEEPSEEK_MODEL = "deepseek-v4-flash";
const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";
// deepseek-v4-flash defaults to THINKING mode. For strict-JSON extraction we
// force NON-thinking mode: deterministic, cheaper (no reasoning tokens), and it
// keeps json_object output clean. Flip to {type:"enabled"} only if you ever want
// reasoning for a task.
const DEEPSEEK_THINKING = { type: "disabled" } as const;
// ─────────────────────────────────────────────────────────────────────────────

const MAX_PAYLOAD_CHARS = 20_000;
const MAX_RECEIPT_CHARS = 2_000_000;

const MONTHLY_LIMITS: Record<Task, number> = {
  receipt_parse: 100,
  maintenance_plan: 50,
};

const COUNTER_TTL_SECONDS = 60 * 60 * 24 * 35; // covers a calendar month
const DAILY_COUNTER_TTL_SECONDS = 60 * 60 * 24 * 2;

// A stolen app binary/shared header must never create an unbounded model bill.
// These are hard installation-wide ceilings; override downward from Vercel env
// during incident response without shipping a new app.
function positiveIntegerEnv(name: string, fallback: number): number {
  const parsed = Number(process.env[name]);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}

const GLOBAL_DAILY_LIMITS: Record<Task, number> = {
  receipt_parse: positiveIntegerEnv("GLOBAL_DAILY_RECEIPT_LIMIT", 2_000),
  maintenance_plan: positiveIntegerEnv("GLOBAL_DAILY_MAINTENANCE_LIMIT", 1_000),
};

const PRO_PRODUCT_IDS = new Set([
  "com.arvia.pro.monthly",
  "com.arvia.pro.yearly",
  "com.arvia.pro.lifetime",
]);
const EXPECTED_BUNDLE_ID = process.env.ARVIA_BUNDLE_ID ?? "com.ruhsatim.app";
const APPLE_PRODUCTION_VERIFY_URL = "https://buy.itunes.apple.com/verifyReceipt";
const APPLE_SANDBOX_VERIFY_URL = "https://sandbox.itunes.apple.com/verifyReceipt";

type Task = "receipt_parse" | "maintenance_plan";

// Per-task system prompts. Temperature 0 + response_format json_object everywhere.
const SYSTEM_PROMPTS: Record<Task, string> = {
  receipt_parse:
    "Türkçe fiş/fatura OCR metninden yapılandırılmış veri çıkarırsın. " +
    "SADECE geçerli JSON döndür; markdown veya açıklama yok. Şema (birebir): " +
    '{"date": string|null (dd.MM.yyyy), "total": number|null, "vendor": string|null, ' +
    '"odometer": number|null, "category": "fuel"|"maintenance"|"insurance"|"tire"|"other", ' +
    '"isMaintenanceInvoice": boolean, "lineItems": [{"description": string, "amount": number}]}. ' +
    "Türk sayı formatında ondalık ayırıcı virgüldür (1.234,56 => 1234.56). " +
    "Bilinmeyen alanlar için null kullan. Değer uydurma.",
  maintenance_plan:
    "Bir araç bakım danışmanısın. Girdi, kullanım profili ve araç özetini içeren JSON'dur. " +
    "SADECE geçerli JSON nesnesi döndür (markdown yok) — şema: " +
    '{"suggestions": [ en fazla 3 adet {"title": string, "message": string, ' +
    '"severity": "info"|"warning"|"important", "suggestedIntervalKm": number|null, ' +
    '"suggestedIntervalMonths": number|null } ]}. ' +
    "title ve message Türkçe olmalı. Öneriler yakıt tipi, günlük km, güzergâh ve araç yaşına dayanmalı. " +
    "En fazla 3 öneri.",
};

// Lazily constructed — NOT at module load. `Redis.fromEnv()` throws
// synchronously if the env vars are missing; doing that at the top level
// crashes the whole function for every request before `handler` even runs
// (opaque "FUNCTION_INVOCATION_FAILED" instead of a readable JSON error).
// Connect Upstash Redis via Vercel → Storage tab to populate these two vars.
function getRedis(): Redis {
  const url = process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN;
  if (!url || !token) {
    throw new MissingEnvError(["UPSTASH_REDIS_REST_URL", "UPSTASH_REDIS_REST_TOKEN"]);
  }
  return new Redis({ url, token });
}

class MissingEnvError extends Error {
  constructor(public readonly vars: string[]) {
    super(`Missing env vars: ${vars.join(", ")}`);
  }
}

function json(status: number, obj: unknown): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json" },
  });
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function monthKey(): string {
  return new Date().toISOString().slice(0, 7); // YYYY-MM
}

function dayKey(): string {
  return new Date().toISOString().slice(0, 10); // YYYY-MM-DD
}

type AppleReceiptItem = {
  product_id?: string;
  transaction_id?: string;
  original_transaction_id?: string;
  expires_date_ms?: string;
  cancellation_date_ms?: string;
};

type AppleReceiptResponse = {
  status?: number;
  receipt?: { bundle_id?: string; in_app?: AppleReceiptItem[] };
  latest_receipt_info?: AppleReceiptItem[];
};

async function callAppleVerifyReceipt(url: string, appReceipt: string): Promise<AppleReceiptResponse> {
  const password = process.env.ARVIA_APP_SHARED_SECRET;
  if (!password) {
    throw new MissingEnvError(["ARVIA_APP_SHARED_SECRET"]);
  }
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      "receipt-data": appReceipt,
      password,
      "exclude-old-transactions": false,
    }),
  });
  if (!response.ok) throw new Error("apple_verify_unreachable");
  return (await response.json()) as AppleReceiptResponse;
}

// Returns a server-derived stable quota key. Client-provided identifiers are
// deliberately not trusted: entitlement and identity both come from Apple.
async function verifyProEntitlement(appReceipt: string): Promise<string | null> {
  let response = await callAppleVerifyReceipt(APPLE_PRODUCTION_VERIFY_URL, appReceipt);
  if (response.status === 21007) {
    response = await callAppleVerifyReceipt(APPLE_SANDBOX_VERIFY_URL, appReceipt);
  }
  if (response.status !== 0 || response.receipt?.bundle_id !== EXPECTED_BUNDLE_ID) {
    return null;
  }

  const now = Date.now();
  const items = [...(response.receipt.in_app ?? []), ...(response.latest_receipt_info ?? [])];
  const valid = items.find((item) => {
    if (!item.product_id || !PRO_PRODUCT_IDS.has(item.product_id) || item.cancellation_date_ms) {
      return false;
    }
    // Non-consumable lifetime purchases have no expiration date.
    return item.product_id === "com.arvia.pro.lifetime" || Number(item.expires_date_ms ?? 0) > now;
  });
  const transactionId = valid?.original_transaction_id ?? valid?.transaction_id;
  return transactionId ? await sha256Hex(transactionId) : null;
}

export default async function handler(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return json(405, { error: { code: "method_not_allowed" } });
  }

  const startupEnv = ["ARVIA_CLIENT_SECRET", "DEEPSEEK_API_KEY"].filter(
    (name) => !process.env[name],
  );
  if (startupEnv.length > 0) {
    return json(500, { error: { code: "server_misconfigured", missing: startupEnv } });
  }

  // Abuse guard: shared header secret. NOTE: this is obfuscation, not security —
  // the secret ships inside the app binary and can be extracted. The real cost
  // ceilings are Apple-entitlement and global Upstash quotas below.
  const clientHeader = req.headers.get("x-arvia-client");
  if (!clientHeader || clientHeader !== process.env.ARVIA_CLIENT_SECRET) {
    return json(401, { error: { code: "unauthorized" } });
  }

  let body: { task?: string; payload?: string; appReceipt?: string };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: { code: "invalid_body" } });
  }

  const task = body.task as Task;
  const payload = body.payload;
  const appReceipt = body.appReceipt;

  if (task !== "receipt_parse" && task !== "maintenance_plan") {
    return json(400, { error: { code: "invalid_task" } });
  }
  if (typeof payload !== "string" || typeof appReceipt !== "string" || appReceipt.length === 0) {
    return json(400, { error: { code: "invalid_request" } });
  }
  if (payload.length > MAX_PAYLOAD_CHARS) {
    return json(413, { error: { code: "payload_too_large", limit: MAX_PAYLOAD_CHARS } });
  }
  if (appReceipt.length > MAX_RECEIPT_CHARS) {
    return json(413, { error: { code: "receipt_too_large", limit: MAX_RECEIPT_CHARS } });
  }

  let entitlementKey: string | null;
  try {
    entitlementKey = await verifyProEntitlement(appReceipt);
  } catch (err) {
    if (err instanceof MissingEnvError) {
      return json(500, { error: { code: "server_misconfigured", missing: err.vars } });
    }
    return json(502, { error: { code: "app_store_verification_failed" } });
  }
  if (!entitlementKey) {
    return json(403, { error: { code: "pro_entitlement_required" } });
  }

  // Constructed here (not at module load) so a missing/misconfigured Upstash
  // connection returns a clean, readable JSON error instead of crashing the
  // whole function invocation for every request.
  let redis: Redis;
  try {
    redis = getRedis();
  } catch (err) {
    if (err instanceof MissingEnvError) {
      return json(500, { error: { code: "server_misconfigured", missing: err.vars } });
    }
    return json(500, { error: { code: "internal_error" } });
  }

  try {
    // ── Rate limits: Apple-derived entitlement identity + global daily ceiling.
    // Reserve counters before the model call so concurrent requests cannot race
    // past the budget. Failed upstream calls still consume a reservation, which
    // intentionally favours bounded cost over retries during an incident.
    const counterKey = `count:${task}:${entitlementKey}:${monthKey()}`;
    const used = await redis.incr(counterKey);
    if (used === 1) await redis.expire(counterKey, COUNTER_TTL_SECONDS);
    if (used > MONTHLY_LIMITS[task]) {
      return json(429, {
        error: { code: "quota_exceeded", task, limit: MONTHLY_LIMITS[task] },
      });
    }

    const globalCounterKey = `global:${task}:${dayKey()}`;
    const globalUsed = await redis.incr(globalCounterKey);
    if (globalUsed === 1) await redis.expire(globalCounterKey, DAILY_COUNTER_TTL_SECONDS);
    if (globalUsed > GLOBAL_DAILY_LIMITS[task]) {
      return json(429, { error: { code: "global_quota_exceeded", task } });
    }

    // ── Call DeepSeek (temperature 0, forced JSON).
    let upstream: Response;
    try {
      upstream = await fetch(DEEPSEEK_URL, {
        method: "POST",
        headers: {
          authorization: `Bearer ${process.env.DEEPSEEK_API_KEY}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model: DEEPSEEK_MODEL,
          temperature: 0,
          thinking: DEEPSEEK_THINKING,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: SYSTEM_PROMPTS[task] },
            { role: "user", content: payload },
          ],
        }),
      });
    } catch {
      return json(502, { error: { code: "upstream_unreachable" } });
    }

    if (!upstream.ok) {
      return json(502, { error: { code: "upstream_error", status: upstream.status } });
    }

    const completion = await upstream.json();
    const content: string | undefined = completion?.choices?.[0]?.message?.content;
    if (!content) {
      return json(502, { error: { code: "empty_completion" } });
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(content);
    } catch {
      return json(502, { error: { code: "model_returned_invalid_json" } });
    }

    // maintenance_plan external contract is a JSON array; the model returns
    // {suggestions:[...]} to satisfy json_object mode, so unwrap it here.
    let result: unknown = parsed;
    if (task === "maintenance_plan") {
      const suggestions = (parsed as { suggestions?: unknown })?.suggestions;
      result = Array.isArray(suggestions) ? suggestions.slice(0, 3) : Array.isArray(parsed) ? parsed : [];
    }

    // Model input/output is never persisted. Only hashed entitlement counters
    // are stored in Redis; quota was reserved before the upstream call.
    return json(200, { result, cached: false });
  } catch {
    // Any unforeseen failure (e.g. Redis unreachable) — never let the platform
    // surface an opaque crash; always return readable JSON.
    return json(500, { error: { code: "internal_error" } });
  }
}
