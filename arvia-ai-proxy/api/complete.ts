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

const MONTHLY_LIMITS: Record<Task, number> = {
  receipt_parse: 100,
  maintenance_plan: 50,
};

const CACHE_TTL_SECONDS = 60 * 60 * 24 * 30; // 30 days
const COUNTER_TTL_SECONDS = 60 * 60 * 24 * 35; // covers a calendar month

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

export default async function handler(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return json(405, { error: { code: "method_not_allowed" } });
  }

  // Abuse guard: shared header secret. NOTE: this is obfuscation, not security —
  // the secret ships inside the app binary and can be extracted. The real cost
  // ceiling is the per-clientId Upstash quota below.
  const clientHeader = req.headers.get("x-arvia-client");
  if (!clientHeader || clientHeader !== process.env.ARVIA_CLIENT_SECRET) {
    return json(401, { error: { code: "unauthorized" } });
  }

  let body: { task?: string; payload?: string; clientId?: string };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: { code: "invalid_body" } });
  }

  const task = body.task as Task;
  const payload = body.payload;
  const clientId = body.clientId;

  if (task !== "receipt_parse" && task !== "maintenance_plan") {
    return json(400, { error: { code: "invalid_task" } });
  }
  if (typeof payload !== "string" || typeof clientId !== "string" || clientId.length === 0) {
    return json(400, { error: { code: "invalid_request" } });
  }
  if (payload.length > MAX_PAYLOAD_CHARS) {
    return json(413, { error: { code: "payload_too_large", limit: MAX_PAYLOAD_CHARS } });
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
    // TEMP diagnostic: `detail` is the exception message only (never request
    // content), returned in the HTTP response — not persisted/logged anywhere.
    // Remove once the proxy is confirmed working end-to-end.
    return json(500, { error: { code: "internal_error", detail: String(err) } });
  }

  try {
    // ── Cache: SHA-256(task + payload). A hit returns without calling the
    //    model and WITHOUT incrementing the quota counter. Only hashes touch Redis.
    const cacheKey = `cache:${task}:${await sha256Hex(task + payload)}`;
    const cached = await redis.get(cacheKey);
    if (cached !== null && cached !== undefined) {
      return json(200, { result: cached, cached: true });
    }

    // ── Rate limit: per clientId monthly counter.
    const counterKey = `count:${task}:${clientId}:${monthKey()}`;
    const used = Number((await redis.get<number>(counterKey)) ?? 0);
    if (used >= MONTHLY_LIMITS[task]) {
      return json(429, {
        error: { code: "quota_exceeded", task, limit: MONTHLY_LIMITS[task] },
      });
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

    // Increment quota (first write sets the monthly TTL) and cache the result.
    const count = await redis.incr(counterKey);
    if (count === 1) {
      await redis.expire(counterKey, COUNTER_TTL_SECONDS);
    }
    await redis.set(cacheKey, result, { ex: CACHE_TTL_SECONDS });

    return json(200, { result, cached: false });
  } catch (err) {
    // Any unforeseen failure (e.g. Redis unreachable) — never let the platform
    // surface an opaque crash; always return readable JSON.
    // TEMP diagnostic: `detail` is the exception message only (never request
    // content). Remove once the proxy is confirmed working end-to-end.
    return json(500, { error: { code: "internal_error", detail: String(err) } });
  }
}
