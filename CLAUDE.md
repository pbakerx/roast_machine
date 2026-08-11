# CLAUDE.md — Roast Machine

Context for AI coding assistants working on this project.

## What this app is
An iOS "roast machine": the user points the camera at their face (or picks a
photo), chooses a comedic persona ("mode"), and the app speaks a roast/compliment
out loud. Pipeline: **OpenAI `gpt-4o` vision → roast script → ElevenLabs TTS → playback.**

## ⚠️ Canonical location (read first)
- **Work here:** `/Users/philipbaker/Software Development/RoastMachine 2.0` (non-cloud drive, this repo).
- **Stale copy — do NOT use:** `/Users/philipbaker/Documents/Client Work/pb/RoastMachine 2.0`
  (old iCloud copy, original graphics, no git repo). It has caused "old version"
  build confusion. If Xcode opens a project titled RoastMachine, confirm the path
  is under **Software Development** before building.

## Build & run
1. Open `RoastMachine.xcodeproj` (Xcode 16, objectVersion 70, iOS 18.5, Swift 5).
2. API keys live in `Secrets.xcconfig` (git-ignored) and flow into the app via
   `RoastMachine-Info.plist` → read in `AppConfig.swift` from `Bundle.main.infoDictionary`.
3. Signing: team `55Y3LX4J5J`, bundle id `AechTech.RoastMachine`, automatic signing.
4. StoreKit testing: Edit Scheme ▸ Run ▸ Options ▸ StoreKit Configuration ▸
   `Subscriptions.storekit`, or products come back empty and the paywall spins.

## Architecture (`RoastMachine/`)
- `RoastMachineApp.swift` — entry; owns `StoreManager`.
- `Models/AppConfig.swift` — reads API keys.
- `Models/RoastMode.swift` — 14 modes (2 free + 12 premium): persona prompt + ElevenLabs voice id + icon.
- `Models/ModeTheme.swift` — per-mode "scene" (colors, backdrop motifs, face-guide shape, hint). Comedy club, kitchen, red carpet, etc.
- `Services/RoastScriptService.swift` — OpenAI vision → roast text.
- `Services/VoiceService.swift` — ElevenLabs TTS + AVAudioPlayer.
- `Services/RoastEngine.swift` — `@MainActor` pipeline orchestrator + phase state.
- `Store/StoreManager.swift` — StoreKit 2 freemium.
- `Views/RootView.swift` — nav; pushes ResultView when a roast starts.
- `Views/HomeView.swift` — the **Stage**: camera-first, full-screen preview, themed
  face overlay, mechanical control panel. Photo library is a small secondary option.
- `Views/StageComponents.swift` — tactile UI kit: `MetalPanel`, `ModeDial` (knurled
  knobs), `ShutterButton`, `FaceGuideOverlay`, `ThematicBackdrop`, `SceneScrim`, `Haptics`.
- `Views/LivePortraitView.swift` — houses `CameraController` + `CameraPreview` (AVCaptureSession) reused by the Stage.
- `Views/ResultView.swift` — themed playback of the roast (transcript + audio + share).
- `Views/ImagePicker.swift` — `ShareSheet` (+ legacy `CameraPicker`, currently unused).

## Important flags & conventions
- **Dev unlock:** `StoreManager.devUnlockEverything = true` unlocks all premium modes
  without purchase. **Set to `false` before TestFlight / App Store.**
- Content safety: every roast is framed by `RoastMode.sharedPreamble` as a comedian
  practising on an *old photo of the user* — forbids cruelty, protected
  characteristics, profanity. Users should only roast their own photos (App Review).
- API keys are shipped client-side (fine for MVP/TestFlight). Move calls behind a
  backend proxy before a wide public launch.

## Known-good next steps / ideas
- Real per-mode background art in the asset catalog (replacing procedural backdrops).
- Voice preview on each mode knob.
- Export roast as a video clip (photo + audio) for sharing.
- App icon (currently default).

## Git
- Local repo on `main`. Remote: `https://github.com/pbakerx/roast_machine.git`
  (add with `git remote add origin …` then `git push -u origin main`).
- `Secrets.xcconfig` is git-ignored — never commit API keys.
