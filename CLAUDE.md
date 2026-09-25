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
2. API keys live in `Secrets.xcconfig` (git-ignored) and flow into the app via
   `RoastMachine-Info.plist` → read in `AppConfig.swift` from `Bundle.main.infoDictionary`.
   Keys: `OPENAI_API_KEY`, `ELEVENLABS_API_KEY` (source of truth:
   `~/Software Development/MasterTechNotesForClaude/secret.txt`).
3. Signing: team `55Y3LX4J5J`, bundle id `AechTech.RoastMachine`, automatic signing.
   Bump `CURRENT_PROJECT_VERSION` for every App Store Connect upload.
4. Tests: `RoastMachineTests` (unit, hosted in the app; folder-synced) — prompt
   assembly and store gating. Run:
   `xcodebuild -project RoastMachine.xcodeproj -scheme RoastMachine -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5' test`
5. StoreKit: the **shared scheme** pins `Subscriptions.storekit` for Xcode-launched
   runs. Apps launched any other way (`simctl launch`, TestFlight, device) hit the
   real sandbox product in App Store Connect.

## Monetization
- Every install gets **one free roast and one free hype** (any comedian). Flags
  persist in UserDefaults (`rm.freeRoastUsed`, `rm.freeHypeUsed`).
- After that the shutter opens the paywall: one **$2.99 non-consumable
  "Everything"** (`AechTech.RoastMachine.allmodes`) unlocks unlimited runs of all
  14 comedians forever. No subscriptions, no credits.
- `StoreManager.devUnlockEverything` stays **`false`**. Only flip locally for UI work.

## Architecture (`RoastMachine/`)
- `RoastMachineApp.swift` — entry; owns `StoreManager`, loads products + entitlements.
- `Models/AppConfig.swift` — API keys + `privacyPolicyURL`.
- `Models/RoastMode.swift` — 14 modes (`classic` + 13 `guests`): persona prompt,
  ElevenLabs voice id, icon, `previewLine`. `RoastFlavor` (`.roast` / `.compliment`)
  picks `sharedPreamble` or `complimentPreamble` in `fullPrompt(flavor:)`.
- `Models/ModeTheme.swift` — per-mode "scene" (colors, painted backdrop image name, face-guide shape, hint).
- `Services/RoastScriptService.swift` — OpenAI vision → script for a mode + flavor.
- `Services/VoiceService.swift` — ElevenLabs TTS + AVAudioPlayer; voice previews cached in Caches.
- `Services/RoastEngine.swift` — `@MainActor` pipeline orchestrator + phase state;
  forwards `VoiceService` change notifications.
- `Services/VideoExporter.swift` — photo + audio + mode badge → shareable 1080×1920 MP4.
- `Store/StoreManager.swift` — StoreKit 2: free-run flags, `canRun(flavor)`,
  `consumeFreeRun`, purchase/restore.
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
- `Views/PaywallView.swift` — lineup grid, one buy button, restore, policy link.
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
- API keys ship client-side (MVP). Move calls behind a backend proxy before a wide launch.

## Known-good next steps / ideas
- Streamed TTS playback (start audio before the full clip arrives).
- Backend proxy for API keys.

## Git
- `main` tracks `https://github.com/pbakerx/roast_machine.git` (public repo).
- `Secrets.xcconfig` is git-ignored — never commit API keys.
