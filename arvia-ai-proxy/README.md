# arvia-ai-proxy

Stateless Vercel **Edge Function** that proxies chat-completion requests to
DeepSeek V4 for the Arvia iOS app. The client never holds the model API key.

- One endpoint: `POST /api/complete`
- Model is a single const (`DEEPSEEK_MODEL = "deepseek-v4-flash"`) — swapping to Gemini is one edit + one adapter.
- Runs in **non-thinking mode** (`thinking: {type:"disabled"}`) with `temperature: 0` and forced JSON output — deterministic, cheap, clean JSON. `deepseek-v4-flash` defaults to thinking mode, so this is set explicitly.
- Endpoint (OpenAI-compatible format): `https://api.deepseek.com/chat/completions`.
- Server-verified App Store Pro entitlement, entitlement-based monthly quotas,
  and installation-wide daily cost ceilings via Upstash Redis.
- **No model input or output is logged or persisted.** Only counters keyed by a
  SHA-256 hash of the verified App Store transaction touch Redis.

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
{ "task": "receipt_parse" | "maintenance_plan", "payload": "<string>", "appReceipt": "<base64 App Store receipt>" }
```

- `receipt_parse` → `{ "result": { date, total, vendor, odometer, category, isMaintenanceInvoice, lineItems[] }, "cached": bool }`
- `maintenance_plan` → `{ "result": [ up to 3 { title, message, severity, suggestedIntervalKm?, suggestedIntervalMonths? } ], "cached": bool }`

Error shape (all non-2xx): `{ "error": { "code": "<machine_readable>" , ... } }`
Notable codes: `unauthorized` (401), `pro_entitlement_required` (403),
`payload_too_large` (413), `quota_exceeded` (429), `upstream_error` (502).

## Environment variables

| Name | Purpose |
| --- | --- |
| `DEEPSEEK_API_KEY` | DeepSeek API key (server-side only). |
| `ARVIA_CLIENT_SECRET` | Shared header secret checked against `X-Arvia-Client`. Obfuscation, not security. |
| `ARVIA_APP_SHARED_SECRET` | App Store Connect app-specific shared secret used only server-side for receipt verification. |
| `ARVIA_BUNDLE_ID` | Expected receipt bundle ID; defaults to `com.ruhsatim.app`. |
| `GLOBAL_DAILY_RECEIPT_LIMIT` | Optional hard daily receipt model-call ceiling (default 2000). |
| `GLOBAL_DAILY_MAINTENANCE_LIMIT` | Optional hard daily maintenance model-call ceiling (default 1000). |
| `UPSTASH_REDIS_REST_URL` | Upstash Redis REST URL (quota sayaçları). |
| `UPSTASH_REDIS_REST_TOKEN` | Upstash Redis REST token. |

## Deploy (Vercel CLI)

```bash
cd arvia-ai-proxy
npm install
npx vercel login

# add env vars to all environments (paste the value when prompted)
npx vercel env add DEEPSEEK_API_KEY production
npx vercel env add ARVIA_CLIENT_SECRET production
npx vercel env add ARVIA_APP_SHARED_SECRET production
npx vercel env add ARVIA_BUNDLE_ID production
npx vercel env add UPSTASH_REDIS_REST_URL production
npx vercel env add UPSTASH_REDIS_REST_TOKEN production

# first deploy (preview) then production
npx vercel
npx vercel --prod
```

Create the Upstash Redis database from the Vercel Marketplace (Storage → Upstash
Redis); it injects `UPSTASH_REDIS_REST_URL` / `UPSTASH_REDIS_REST_TOKEN` automatically.

## Example calls

Replace `$URL`, `$SECRET`, and `$APP_RECEIPT` with your deployment values.
Receipt enforcement must be deployed together with the 1.1 client; older clients
do not send `appReceipt` and will receive 403 after enforcement is live.

### 1) receipt_parse — success

```bash
curl -s -X POST "$URL/api/complete" \
  -H "X-Arvia-Client: $SECRET" \
  -H "Content-Type: application/json" \
  -d '{"task":"receipt_parse","appReceipt":"'$APP_RECEIPT'",
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
  -d '{"task":"maintenance_plan","appReceipt":"'$APP_RECEIPT'",
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
for an Apple-verified Pro entitlement:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$URL/api/complete" \
  -H "X-Arvia-Client: $SECRET" \
  -H "Content-Type: application/json" \
  -d '{"task":"maintenance_plan","appReceipt":"'$APP_RECEIPT'","payload":"{}"}'
# 429
```

Body:

```json
{ "error": { "code": "quota_exceeded", "task": "maintenance_plan", "limit": 50 } }
```
