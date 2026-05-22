# AI Headshot

**LinkedIn Photo · Professional Portrait Generator**

A mobile-first iOS app that turns 3–5 selfies into 20 studio-quality professional headshots in under 30 seconds, powered by FLUX.1 + InstantID via fal.ai.

## Repository Structure

```
ai-headshot/
├── ios/                    # iOS App (Swift / SwiftUI)
│   ├── App/                # Entry point, navigation coordinator
│   ├── Features/           # Screen-level views and view models
│   │   ├── Camera/         # AVFoundation preview, Vision quality checks
│   │   ├── Generation/     # Style selector, progress, results gallery
│   │   ├── Paywall/        # RevenueCat subscription UI
│   │   ├── Settings/       # Account, privacy, data deletion
│   │   ├── Onboarding/     # 3-slide intro
│   │   └── Home/           # Dashboard + recent jobs
│   ├── Services/           # APIClient (URLSession), HeadshotService (SSE)
│   ├── Models/             # Job, ProgressEvent, UserEntitlement
│   └── Resources/          # Localizable.strings
│
└── backend/                # Node.js / Fastify API
    ├── src/
    │   ├── index.ts         # Fastify bootstrap
    │   ├── config/env.ts    # Zod-validated env vars
    │   ├── routes/          # jobs, users, webhooks, templates
    │   ├── queue/           # BullMQ worker (6-step pipeline)
    │   ├── services/        # fal.ai, Cloudflare R2, OneSignal push
    │   ├── db/              # Supabase client, schema.sql, repos
    │   └── middleware/      # JWT auth, rate limiting
    └── tests/               # Vitest unit tests
```

## Tech Stack

| Layer | Technology |
|---|---|
| iOS | Swift 5.9 / SwiftUI / AVFoundation / Vision |
| Backend | Node.js 20 / Fastify / TypeScript |
| Task Queue | BullMQ + Upstash Redis |
| Database | PostgreSQL via Supabase |
| AI Generation | FLUX.1 Dev + InstantID via fal.ai |
| Face Analysis | InsightFace (ArcFace) via fal.ai |
| Storage | Cloudflare R2 (24h TTL) |
| Subscriptions | RevenueCat |
| Push | OneSignal → APNs |

## Quick Start

See [SETUP.md](./SETUP.md) for full setup instructions.

```bash
# Backend
cd backend && npm install
cp .env.example .env   # fill in all keys
npm run dev            # API server
npm run worker         # BullMQ worker (separate terminal)
```

For the iOS app: open Xcode, create a new SwiftUI project, add the `ios/` source files, and install RevenueCat via Swift Package Manager.

## Features

- **Guided camera capture** — real-time face quality checks (angle, brightness, sharpness) via Apple Vision framework
- **Auto-capture** — 1.5s quality hold → 3s countdown → haptic feedback → auto-shot
- **Multi-step progress** — SSE streaming from backend with fake-progress fill
- **Style selector** — 6 industries × 3 styles, saved in `@AppStorage`
- **Results gallery** — 2-col grid, pinch-to-zoom, download/share/LinkedIn deeplink
- **Paywall** — RevenueCat packages, $9.99/mo or $59.99/yr, 7-day free trial
- **Privacy** — 24h auto-delete with visible countdown, "Delete My Data" GDPR button

## License

MIT
