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
- **Source of truth (work here):** the NAS folder
  `/Volumes/Home/02. Project Files/01. Software Development/roast machine`
  (THEVAULT, mounted at `/Volumes/Home`). This folder is the git repo; `main`
  tracks `github.com/pbakerx/roast_machine`. Moved here 2026-09-28 at `9cf0d63`.
- **Old copies, kept but do NOT use** (each has a `DO-NOT-USE-README.txt`):
  - `/Users/philipbaker/Software Development/RoastMachine 2.0 (OLD-see-NAS)`:
    the working copy until 2026-09-28, frozen identical to the NAS at `9cf0d63`.
  - `/Users/philipbaker/Documents/Client Work/pb/RoastMachine 2.0 (OLD-see-NAS)`:
    July iCloud copy, original graphics, no git repo.
  If Xcode opens a project titled RoastMachine, confirm the path is on
  `/Volumes/Home/...` before building.
- `DATABASE.md` and `supabase-multi-app-handoff.md` sit beside the repo on the
  NAS but are excluded from git (`.git/info/exclude`). They describe the shared
  Supabase project; never commit them to this public repo.
- Git on the NAS share: if git says "another git process seems to be running",
  move the stale `.lock` file into `.git/trash/` (rename works where delete may
  not). See `00. MasterTechNotesForClaude/MOVING-PROJECTS-RUNBOOK.md`.

## Build, run, test
1. Open `RoastMachine.xcodeproj` (Xcode 26, objectVersion 70, iOS 18.5 target, Swift 5). iPhone-only, portrait-only.
2. **The app ships no API keys.** OpenAI + ElevenLabs are called by the backend
   (below). `Secrets.xcconfig` (git-ignored) still holds the raw keys for local
   scripts and `RM_DEV_TOKEN` for the simulator, but nothing in it reaches the app.
3. Signing: team `55Y3LX4J5J`, bundle id `AechTech.RoastMachine`, automatic signing,
   App Attest entitlement in `RoastMachine.entitlements`.
   Bump `CURRENT_PROJECT_VERSION` for every App Store Connect upload.
4. Tests: `RoastMachineTests` (catalog ↔ server personas, voices ↔ server
   `VOICE_CATALOG`, bundled voice samples + sold-out clips, sold-out strike count,
   wallet gating). Run on the dedicated sim "RM-Shots iPhone 17 Pro Max"
   (AED246CA…); iPad compatibility checks on "RM-iPad" (iPad Pro 13-inch, 64365EEF…).
   Philip runs other Xcode sessions, so don't reuse or quit his simulators/Xcode.
   Purchases only work in TestFlight builds (or with a sandbox test account);
   a build installed straight from Xcode rejects a normal Apple account.
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
- `_shared/personas.ts` — **source of truth** for comedian prompts, the
  `VOICE_CATALOG` (8 pickable voices, key → ElevenLabs id; defaults larry/ace)
  and ticket products. The app sends a mode id and a voice key, never a prompt
  or a voice id; unknown keys fall back to the default, and a voice its owner
  disabled falls back to a premade one (`FALLBACK_VOICES`).
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
- Economics (measured 2026-09-28): ~2.5¢ per show. Scripts average ~285 chars
  (roast ~271, hype ~298) on ElevenLabs multilingual v2 at the published
  $0.08/1k ≈ 2.3¢, plus gpt-4o ≈ 0.2¢. ElevenLabs plan: Creator, $22/month.
  At today's pack prices that's ~82–88% gross margin after Apple's 15%.
- The wallet id is a random UUID in the iCloud Keychain (`Backend.swift`), so
  tickets survive reinstalls. Transactions are finished only after the server credits them.

## Architecture (`RoastMachine/`)
- `RoastMachineApp.swift` — entry; owns `StoreManager`, loads products + entitlements.
- `Models/AppConfig.swift` — backend URL + `privacyPolicyURL` (no keys).
- `Models/RoastMode.swift` — 14 modes (`classic` + 13 `guests`): title, icon, tint;
  `RoastFlavor` (`.roast` / `.compliment`). Prompts are server-side.
- `Models/Voice.swift` — the 8 voices (key, name, vibe, emoji). Keys must match
  `VOICE_CATALOG`. The choice is per flavor: `rm.voice.roast` / `rm.voice.hype`.
- `Models/ModeTheme.swift` — per-mode "scene" (colors, painted backdrop image name, face-guide shape, hint).
- `Services/Backend.swift` — App Attest signing, wallet id (Keychain), calls to the Edge Function, `Wallet`.
- `Services/VoiceService.swift` — AVAudioPlayer playback of shows, voice samples
  (`Previews/voice_<key>_<roast|hype>.mp3`) and sold-out roasts
  (`Previews/soldout_<key>_<1|2|3>.mp3`). Re-record all of them with
  `scripts/record_previews.py [samples|soldout|all] [voice …]` after changing voices.
- `Services/RoastEngine.swift` — `@MainActor` show orchestrator (server `show` → `voice`) + phase state.
- `Services/VideoExporter.swift` — photo + audio + mode badge → shareable 1080×1920 MP4.
- `Store/StoreManager.swift` — Box Office: ticket packs, wallet from the server,
  purchase → server credit → finish. Also the sold-out strike count
  (`rm.soldOutStrikes`, 1 → 2 → 3 and holds; resets when tickets > 0).
- `Views/RootView.swift` — nav; pushes ResultView when a run starts.
- `Views/HomeView.swift` — the **Stage**: camera-first, themed face guide, ticket
  banner (free runs left / unlock pitch), mechanical control panel with the
  ROAST/HYPE rocker + `VoicePill`. Shutter gates on `store.canRun` → escalating
  sold-out roast in the chosen voice + Box Office, then on AI consent → `AIConsentView`.
- `Views/AIConsentView.swift` — one-time "Before the Show" disclosure + permission
  (App Review 5.1.2(i): third-party AI data sharing). Stored in `rm.aiConsentGiven`.
- `Views/VoicePickerView.swift` — sheet of voice cards; tap selects + plays a sample.
- `Views/StageComponents.swift` — tactile UI kit: `MetalPanel`, `ModeDial`,
  `FlavorSwitch` (ROAST/HYPE rocker), `VoicePill`, `ShutterButton`, `FaceGuideOverlay`,
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
  shows the paid experience. Also `RM_DEMO_MODE`, `RM_DEMO_FLAVOR`, `RM_DEMO_AUTORUN=1`
  (accept consent + fire the shutter), `RM_DEMO_BOXOFFICE=1`, `RM_DEMO_VOICE=<key>`,
  `RM_DEMO_VOICEPICKER=1`, `RM_DEMO_SOLDOUT=1` (empty wallet: with AUTORUN it
  plays the next sold-out roast), and `RM_DEMO_WALLET=<tickets>,<0|1>,<0|1>`
  (any balance; `0,1,1` shows the fresh-install "on the house" banner).

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
