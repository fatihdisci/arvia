# arvia-ai-proxy

Stateless Vercel **Edge Function** that proxies chat-completion requests to
DeepSeek V4 for the Arvia iOS app. The client never holds the model API key.

- One endpoint: `POST /api/complete`
- Model is a single const (`DEEPSEEK_MODEL = "deepseek-v4-flash"`) — swapping to Gemini is one edit + one adapter.
- Runs in **non-thinking mode** (`thinking: {type:"disabled"}`) with `temperature: 0` and forced JSON output — deterministic, cheap, clean JSON. `deepseek-v4-flash` defaults to thinking mode, so this is set explicitly.
- Endpoint (OpenAI-compatible format): `https://api.deepseek.com/chat/completions`.
- Per-`clientId` monthly quotas + 30-day response cache via Upstash Redis.
- **No payload content is ever logged.** Only counters and cache keys (SHA-256 hashes) touch Redis.

## File tree

```
arvia-ai-proxy/
├── api/
│   └── complete.ts      # the Edge Function (all logic)
├── package.json
├── tsconfig.json
├── vercel.json          # pins api/complete.ts to the edge runtime
├── .gitignore
└── README.md
```

## Request / response

`POST /api/complete`
Headers: `X-Arvia-Client: <shared secret>`, `Content-Type: application/json`
Body:

```json
{ "task": "receipt_parse" | "maintenance_plan", "payload": "<string>", "clientId": "<anonymous uuid>" }
```

- `receipt_parse` → `{ "result": { date, total, vendor, odometer, category, isMaintenanceInvoice, lineItems[] }, "cached": bool }`
- `maintenance_plan` → `{ "result": [ up to 3 { title, message, severity, suggestedIntervalKm?, suggestedIntervalMonths? } ], "cached": bool }`

Error shape (all non-2xx): `{ "error": { "code": "<machine_readable>" , ... } }`
Notable codes: `unauthorized` (401), `payload_too_large` (413), `quota_exceeded` (429), `upstream_error` (502).

## Environment variables

| Name | Purpose |
| --- | --- |
| `DEEPSEEK_API_KEY` | DeepSeek API key (server-side only). |
| `ARVIA_CLIENT_SECRET` | Shared header secret checked against `X-Arvia-Client`. Obfuscation, not security. |
| `UPSTASH_REDIS_REST_URL` | Upstash Redis REST URL (quotas + cache). |
| `UPSTASH_REDIS_REST_TOKEN` | Upstash Redis REST token. |

## Deploy (Vercel CLI)

```bash
cd arvia-ai-proxy
npm install
vercel login

# add env vars to all environments (paste the value when prompted)
vercel env add DEEPSEEK_API_KEY production
vercel env add ARVIA_CLIENT_SECRET production
vercel env add UPSTASH_REDIS_REST_URL production
vercel env add UPSTASH_REDIS_REST_TOKEN production

# first deploy (preview) then production
vercel
vercel --prod
```

Create the Upstash Redis database from the Vercel Marketplace (Storage → Upstash
Redis); it injects `UPSTASH_REDIS_REST_URL` / `UPSTASH_REDIS_REST_TOKEN` automatically.

## Example calls

Replace `$URL` with your deployment and `$SECRET` with `ARVIA_CLIENT_SECRET`.

### 1) receipt_parse — success

```bash
curl -s -X POST "$URL/api/complete" \
  -H "X-Arvia-Client: $SECRET" \
  -H "Content-Type: application/json" \
  -d '{"task":"receipt_parse","clientId":"11111111-1111-1111-1111-111111111111",
       "payload":"OPET AKARYAKIT\nTarih: 15.03.2024\nMOTORIN\nTOPLAM: 1.079,50 TL"}'
```

Expected:

```json
{
  "result": {
    "date": "15.03.2024",
    "total": 1079.5,
    "vendor": "OPET AKARYAKIT",
    "odometer": null,
    "category": "fuel",
    "isMaintenanceInvoice": false,
    "lineItems": [{ "description": "MOTORIN", "amount": 1079.5 }]
  },
  "cached": false
}
```

### 2) maintenance_plan — success

```bash
curl -s -X POST "$URL/api/complete" \
  -H "X-Arvia-Client: $SECRET" \
  -H "Content-Type: application/json" \
  -d '{"task":"maintenance_plan","clientId":"11111111-1111-1111-1111-111111111111",
       "payload":"{\"fuelType\":\"lpg\",\"dailyKm\":80,\"routeType\":\"city\",\"ageYears\":7,\"odometer\":95000}"}'
```

Expected:

```json
{
  "result": [
    { "title": "Triger seti kontrolü", "message": "100.000 km'ye yaklaşıyorsun; triger seti kontrol edilmeli.", "severity": "important", "suggestedIntervalKm": 5000, "suggestedIntervalMonths": null },
    { "title": "Subap ayarı", "message": "LPG kullanımı subap ayarını daha sık gerektirir.", "severity": "warning", "suggestedIntervalKm": null, "suggestedIntervalMonths": 12 }
  ],
  "cached": false
}
```

### 3) quota_exceeded — 429

After the monthly limit (`receipt_parse` 100 / `maintenance_plan` 50) is reached
for a `clientId`:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$URL/api/complete" \
  -H "X-Arvia-Client: $SECRET" \
  -H "Content-Type: application/json" \
  -d '{"task":"maintenance_plan","clientId":"11111111-1111-1111-1111-111111111111","payload":"{}"}'
# 429
```

Body:

```json
{ "error": { "code": "quota_exceeded", "task": "maintenance_plan", "limit": 50 } }
```
