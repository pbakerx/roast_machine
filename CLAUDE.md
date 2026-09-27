# CLAUDE.md — Roast Machine

Context for AI coding assistants working on this project.

## What this app is
An iOS "roast machine": the user points the camera at their face (or picks a
photo), chooses a comedic persona ("mode"), flips a ROAST/HYPE rocker, and the
app speaks a roast — or an over-the-top compliment — out loud.
Pipeline: **OpenAI `gpt-4o` vision → script → ElevenLabs TTS → playback**.
No images are generated or streamed onto the show — Philip cut both the Gemini
art and the emoji sticker stream as not useful; don't reintroduce them.

## ⚠️ Canonical location (read first)
- **Work here:** `/Users/philipbaker/Software Development/RoastMachine 2.0` (non-cloud drive, this repo).
- **Stale copy — do NOT use:** `/Users/philipbaker/Documents/Client Work/pb/RoastMachine 2.0`
  (old iCloud copy, original graphics, no git repo). It has caused "old version"
  build confusion. If Xcode opens a project titled RoastMachine, confirm the path
  is under **Software Development** before building.

## Build, run, test
1. Open `RoastMachine.xcodeproj` (Xcode 26, objectVersion 70, iOS 18.5 target, Swift 5). iPhone-only, portrait-only.
2. **The app ships no API keys.** OpenAI + ElevenLabs are called by the backend
   (below). `Secrets.xcconfig` (git-ignored) still holds the raw keys for local
   scripts and `RM_DEV_TOKEN` for the simulator, but nothing in it reaches the app.
3. Signing: team `55Y3LX4J5J`, bundle id `AechTech.RoastMachine`, automatic signing,
   App Attest entitlement in `RoastMachine.entitlements`.
   Bump `CURRENT_PROJECT_VERSION` for every App Store Connect upload.
4. Tests: `RoastMachineTests` (catalog ↔ server personas, bundled previews, wallet
   gating). Run on the dedicated sim "RM-Tests iPhone 17 Pro" — Philip runs other
   Xcode sessions, so don't reuse or quit his simulators/Xcode.
   Server tests: `cd supabase/functions && deno test --allow-net --allow-env --allow-read _shared/apple_test.ts`.
5. StoreKit: the shared scheme pins `Subscriptions.storekit` for Xcode-launched runs;
   everything else hits the sandbox/production products in App Store Connect.

## Backend (Supabase — shared Second-Brain project)
- **Never create a Supabase project for this app.** It lives in the existing
  **Second-Brain** project (`jqvohqudydzolyqfijrb`, AechTech org) as schema
  **`app_roastmachine`** — one schema per app. Docs on the NAS:
  `/Volumes/Home/02. Project Files/01. Software Development/roast machine/`.
- `supabase/migrations/20260927000000_app_roastmachine.sql` — wallets, attest_keys,
  challenges, purchases, shows + `spend_show` / `refund_show` / `credit_purchase`.
  RLS on, **no policies**, no grants to anon/authenticated/service_role, schema not
  exposed to PostgREST. Additive, safe to re-run:
  `supabase db query --linked --project-ref jqvohqudydzolyqfijrb --file <migration>`.
- `supabase/functions/roastmachine/` — one Edge Function (`verify_jwt = false`),
  routes `challenge`, `register`, `wallet`, `show`, `voice`, `credit`. Connects to
  Postgres directly via `SUPABASE_DB_URL`. Deploy:
  `supabase functions deploy roastmachine --project-ref jqvohqudydzolyqfijrb --use-api --no-verify-jwt`.
- `_shared/personas.ts` — **source of truth** for comedian prompts + ElevenLabs
  voices + ticket products. The app sends a mode id, never a prompt.
- Security: every request carries an **App Attest** assertion (genuine app on a
  genuine iPhone; counter blocks replay). Purchases are StoreKit 2 JWS verified
  against Apple Root CA G3 and credited once per transaction id, only to the
  wallet in `appAccountToken`. Rate limits: 30 shows/wallet/day, 40/IP-hash/hour,
  3,000/day globally (env `ROASTMACHINE_*_CAP`). One voice per show; scripts are
  deleted once voiced. **Do not enable Supabase anonymous sign-ins** on the shared
  project. Secrets are prefixed `ROASTMACHINE_` (OPENAI_API_KEY, ELEVENLABS_API_KEY,
  IP_SALT, DEV_TOKEN). `ROASTMACHINE_DEV_TOKEN` is a simulator-only bypass —
  `supabase secrets unset ROASTMACHINE_DEV_TOKEN --project-ref …` closes it.

## Monetization — the Box Office
- Every wallet gets **one free roast and one free hype** (server-side flags).
- After that each show costs a **ticket**. Consumable packs: Top-Up 8 / $1.99,
  Opening Act 20 / $3.99, Headliner 60 / $9.99 (`AechTech.RoastMachine.tickets8/20/60`).
- Economics: ~2.8¢ API cost per show (tight ~250-char bits on ElevenLabs
  multilingual v2 at $0.10/1k chars + gpt-4o) → ~77–84% gross margin after Apple's 15%.
- The wallet id is a random UUID in the iCloud Keychain (`Backend.swift`), so
  tickets survive reinstalls. Transactions are finished only after the server credits them.

## Architecture (`RoastMachine/`)
- `RoastMachineApp.swift` — entry; owns `StoreManager`, loads products + entitlements.
- `Models/AppConfig.swift` — backend URL + `privacyPolicyURL` (no keys).
- `Models/RoastMode.swift` — 14 modes (`classic` + 13 `guests`): title, icon, tint,
  `previewLine`; `RoastFlavor` (`.roast` / `.compliment`). Prompts/voices are server-side.
- `Models/ModeTheme.swift` — per-mode "scene" (colors, painted backdrop image name, face-guide shape, hint).
- `Services/Backend.swift` — App Attest signing, wallet id (Keychain), calls to the Edge Function, `Wallet`.
- `Services/VoiceService.swift` — AVAudioPlayer playback; previews play bundled `Previews/preview_<id>.mp3`.
- `Services/RoastEngine.swift` — `@MainActor` show orchestrator (server `show` → `voice`) + phase state.
- `Services/VideoExporter.swift` — photo + audio + mode badge → shareable 1080×1920 MP4.
- `Store/StoreManager.swift` — Box Office: ticket packs, wallet from the server, purchase → server credit → finish.
- `Views/RootView.swift` — nav; pushes ResultView when a run starts.
- `Views/HomeView.swift` — the **Stage**: camera-first, themed face guide, ticket
  banner (free runs left / unlock pitch), mechanical control panel. Shutter gates
  on `store.canRun` → paywall, then on AI consent → `AIConsentView`.
- `Views/AIConsentView.swift` — one-time "Before the Show" disclosure + permission
  (App Review 5.1.2(i): third-party AI data sharing). Stored in `rm.aiConsentGiven`.
- `Views/StageComponents.swift` — tactile UI kit: `MetalPanel`, `ModeDial`,
  `FlavorSwitch` (ROAST/HYPE rocker), `ShutterButton`, `FaceGuideOverlay`,
  `ThematicBackdrop`, `SceneScrim`, `Haptics`.
- `Views/EmberField.swift` — drifting embers for the Classic stage.
- `Views/LivePortraitView.swift` — `CameraController` + `CameraPreview` (AVCaptureSession).
- `Views/ResultView.swift` — audio-first show: full-frame photo,
  CRANK IT UP banner, TRY AGAIN capsule 5s in, transcript sheet, video-first share.
- `Views/PaywallView.swift` — the Box Office: three packs, deal copy, policy link.
- `Views/ImagePicker.swift` — `ShareSheet` (+ legacy `CameraPicker`, unused).

## Web, listing, screenshots
- `docs/` — GitHub Pages site: `index.html` (support) and `privacy.html`
  (Privacy & AI Policy) at `https://pbakerx.github.io/roast_machine/`.
- `marketing/appstore-metadata.md` — listing copy, keywords, privacy-label answers,
  IAP fields, App Review notes. Keep in sync with the app. No celebrity names or
  third-party trademarks in titles/metadata (guideline 5.2.1).
- Screenshots (6.9", 1320×2868): `scripts/make_demo_portrait.py` draws the
  synthetic demo face (`marketing/demo_portrait.jpg`); `scripts/frame_screenshots.py`
  frames raw captures into `marketing/screenshots/`.
- Simulator screenshot rig (DEBUG + simulator only, compiled out of Release):
  `SIMCTL_CHILD_RM_DEMO_PHOTO=<jpg>` drops a photo onto the Stage (the sim has no
  camera and `simctl addmedia` crashes on Xcode 26.6); `SIMCTL_CHILD_RM_DEMO_UNLOCK=1`
  shows the paid experience.

## Art pipeline
Backdrops (`Assets.xcassets/Backdrops/backdrop_<modeid>`) and the app icon are
generated by Python/Pillow in the "Footlight Pop" design language (lit from
below, bold silhouettes, violet shadows). There is no runtime image generation.

## Important conventions
- Content safety: every run is framed by the preamble as a comedian working an
  *old photo of the user* — no cruelty, protected characteristics, or profanity
  beyond "damn". Users should only roast their own photos (App Review).

## Known-good next steps / ideas
- Streamed TTS playback (start audio before the full clip arrives).
- DeviceCheck bits so free runs can't be farmed by wiping the keychain.

## Git
- `main` tracks `https://github.com/pbakerx/roast_machine.git` (public repo).
- `Secrets.xcconfig` is git-ignored — never commit API keys.
