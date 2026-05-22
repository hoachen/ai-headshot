# AI Headshot App — Setup Guide

## Project Structure

```
apps/
├── AIHeadshot/                   # iOS SwiftUI App
│   ├── App/
│   │   ├── AppEntry.swift        # @main entry, RevenueCat init, RootView routing
│   │   └── AppCoordinator.swift  # Navigation state machine (MVVM coordinator)
│   ├── Features/
│   │   ├── Camera/
│   │   │   ├── CameraView.swift       # AVFoundation preview + oval overlay + guide UI
│   │   │   ├── CameraViewModel.swift  # Session, quality check loop, countdown, capture
│   │   │   └── QualityChecker.swift   # Vision framework: face, brightness, sharpness
│   │   ├── Generation/
│   │   │   ├── StyleSelectorView.swift      # Industry + Style picker, @AppStorage
│   │   │   ├── GenerationProgressView.swift # SSE stream + fake progress bar
│   │   │   └── ResultsGalleryView.swift     # 2-col grid, pinch zoom, download/share
│   │   ├── Paywall/
│   │   │   └── PaywallView.swift   # RevenueCat packages, trial CTA, restore
│   │   ├── Settings/
│   │   │   └── SettingsView.swift  # Account, subscription, delete data
│   │   ├── Onboarding/
│   │   │   └── OnboardingView.swift # 3-slide onboarding with page indicator
│   │   └── Home/
│   │       └── HomeView.swift      # Dashboard, recent jobs, CTA
│   ├── Services/
│   │   ├── APIClient.swift        # URLSession, auth, retry, multipart upload
│   │   └── HeadshotService.swift  # submit(), streamProgress(), listJobs()
│   ├── Models/
│   │   ├── Job.swift              # Codable job model
│   │   ├── ProgressEvent.swift    # SSE event model
│   │   └── UserEntitlement.swift  # RevenueCat wrapper
│   └── Resources/
│       └── Localizable.strings    # All UI strings (English)
│
└── headshot-backend/              # Node.js / Fastify Backend
    ├── src/
    │   ├── index.ts               # Fastify bootstrap, plugin registration
    │   ├── config/env.ts          # Zod-validated environment variables
    │   ├── middleware/
    │   │   ├── auth.ts            # JWT sign/verify, FastifyRequest.user injection
    │   │   └── rateLimit.ts      # Global + per-route rate limiting
    │   ├── db/
    │   │   ├── schema.sql         # PostgreSQL DDL + RLS + seed data
    │   │   ├── client.ts          # Supabase client singleton + type definitions
    │   │   ├── jobs.repo.ts       # Job CRUD, status updates
    │   │   └── users.repo.ts      # User/subscription CRUD
    │   ├── routes/
    │   │   ├── jobs.ts            # POST /jobs, GET /jobs/:id/stream, GET /jobs
    │   │   ├── users.ts           # POST /users, DELETE /users/me, GET /health
    │   │   ├── webhooks.ts        # POST /webhooks/revenuecat (HMAC validated)
    │   │   └── templates.ts       # GET /templates
    │   ├── queue/
    │   │   ├── job.types.ts       # JobData, ErrorCode, step→percent mapping
    │   │   ├── headshot.queue.ts  # BullMQ pro + free queue definitions
    │   │   └── headshot.worker.ts # Full 6-step pipeline worker
    │   └── services/
    │       ├── fal.service.ts        # fal.ai: InsightFace, FLUX+InstantID, ESRGAN
    │       ├── r2.service.ts         # Cloudflare R2: upload, delete, presigned URLs
    │       └── apns.service.ts       # OneSignal push notifications
    └── tests/
        ├── jobs.test.ts          # Queue + submission validation tests
        └── quality.test.ts       # Quality threshold + step percent tests
```

---

## iOS Setup (Xcode)

### 1. Create Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Settings:
   - **Product Name**: AIHeadshot
   - **Bundle Identifier**: `com.yourcompany.aiheadshot`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Minimum Deployment**: iOS 16.0

### 2. Add Swift Files

Copy all `.swift` files from `AIHeadshot/` into your Xcode project, preserving the folder structure (App, Features, Services, Models, Resources).

### 3. Swift Package Dependencies

**File → Add Package Dependencies**, add:

| Package | URL | Version |
|---|---|---|
| RevenueCat | `https://github.com/RevenueCat/purchases-ios` | `4.x.x` |

### 4. Info.plist Entries

Add to `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to capture photos for AI headshot generation. Photos are processed securely and deleted within 24 hours.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>To save your generated headshots to your photo library.</string>
```

### 5. Capabilities (Xcode → Signing & Capabilities)

- ✅ Push Notifications
- ✅ In-App Purchase

### 6. Configure API Key

In `AppEntry.swift`, update `AppConfig.baseURL` to your deployed backend URL.

In RevenueCat dashboard, copy your iOS SDK key and set it as `REVENUECAT_API_KEY` in your Xcode scheme environment variables (or replace the placeholder in `AppConfig.revenueCatAPIKey`).

---

## Backend Setup

### 1. Install dependencies

```bash
cd headshot-backend
npm install
```

### 2. Environment variables

```bash
cp .env.example .env
# Fill in all values — see comments in .env.example
```

### 3. Supabase database

1. Create a project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** and run `src/db/schema.sql`
3. Copy the **Project URL** and **service_role key** into `.env`

### 4. Cloudflare R2

1. Create R2 bucket named `headshots-prod`
2. Add lifecycle rule: delete objects older than 86400 seconds
3. Create API token with R2 edit permissions

### 5. fal.ai

1. Sign up at [fal.ai](https://fal.ai)
2. Copy API key to `FAL_KEY` in `.env`

### 6. RevenueCat webhook

In RevenueCat dashboard → **Integrations → Webhooks**:
- URL: `https://your-backend.com/webhooks/revenuecat`
- Copy the shared secret to `REVENUECAT_WEBHOOK_SECRET`

### 7. Run locally

```bash
# Terminal 1 — API server
npm run dev

# Terminal 2 — Background worker
npm run worker
```

### 8. Deploy

**Railway** (recommended):
```bash
# Install Railway CLI
npm install -g @railway/cli
railway login
railway init
railway up
```

Set all `.env` variables in Railway's dashboard. Add two services:
- `web`: runs `npm start`
- `worker`: runs `npm run worker`

---

## Quality Check Thresholds

| Check | Threshold | Vision API |
|---|---|---|
| Face confidence | > 0.7 | `VNDetectFaceLandmarksRequest` |
| Yaw (horizontal) | < 0.44 rad (≈25°) | `observation.yaw` |
| Pitch (vertical) | < 0.35 rad (≈20°) | `observation.pitch` |
| Brightness | luminance mean > 80 | Manual pixel sampling |
| Sharpness | Laplacian variance > 100 | vImage convolution |
| Face size | > 20% of frame area | `boundingBox.width × height` |

---

## API Reference

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/users` | None | Sign in with Apple, returns JWT |
| POST | `/jobs` | JWT | Submit generation (multipart/form-data) |
| GET | `/jobs/:id/stream` | JWT | SSE progress stream |
| GET | `/jobs/:id` | JWT | Poll job status |
| GET | `/jobs` | JWT | List recent 20 jobs |
| DELETE | `/jobs/:id/photos` | JWT | Early photo deletion |
| DELETE | `/users/me` | JWT | GDPR account deletion |
| POST | `/webhooks/revenuecat` | HMAC | RevenueCat events |
| GET | `/templates` | JWT | Available style templates |
| GET | `/health` | None | Health check |

---

## SSE Event Format

```json
{ "state": "GENERATING", "pct": 65, "urls": null }
{ "state": "DONE", "pct": 100, "urls": ["https://..."] }
{ "state": "FAILED", "pct": 0, "error": "NO_FACE_DETECTED" }
```

---

## Cost Estimates (1,000 paid users/month)

| Item | Cost |
|---|---|
| AI Generation (FLUX, 20 img) | ~$800 |
| AI Preview (SD, free users) | ~$60 |
| InsightFace embedding | ~$8 |
| Cloudflare R2 | ~$20 |
| Redis (Upstash) | ~$10 |
| Server (Railway) | ~$20 |
| **Total COGS** | **~$918** |
| **Net profit (after Apple 30%)** | **~$6,075** |
