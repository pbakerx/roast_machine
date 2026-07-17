# Roast Machine

Feed it a face, pick a mode, and get roasted (or adored) out loud. Vision model
writes the bit, ElevenLabs speaks it.

## Stack
- SwiftUI, iOS 18.5+, Swift 5 (matches the AssistAI project settings)
- Team `55Y3LX4J5J`, bundle id `AechTech.RoastMachine`, automatic signing
- OpenAI `gpt-4o` for image → script, ElevenLabs TTS for the voice
- StoreKit 2 freemium: two free modes, small one-time unlocks

## First-time setup
1. Open the project:
   ```sh
   open "RoastMachine.xcodeproj"
   ```
2. Add your API keys to `Secrets.xcconfig` (already git-ignored):
   ```
   OPENAI_API_KEY = sk-...
   ELEVENLABS_API_KEY = sk_...
   ```
   The keys flow into the app via `RoastMachine-Info.plist` (the same pattern
   AssistAI uses). Nothing else to wire up.
3. Select an iPhone simulator or your device and hit Run.

## Build from the terminal
```sh
# Debug build for a simulator
xcodebuild -project "RoastMachine.xcodeproj" -scheme RoastMachine \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```
> On first run Xcode auto-creates the shared scheme from the single target.
> If `-scheme RoastMachine` isn't found yet, open the project in Xcode once so it
> generates the scheme, then the command above works.

## In-app purchases (testing)
`Subscriptions.storekit` is included with three products:
- `AechTech.RoastMachine.allmodes` — unlock every persona ($1.99)
- `AechTech.RoastMachine.voices` — premium voices ($0.99)
- `AechTech.RoastMachine.credits20` — consumable credit pack ($0.99)

To test locally: Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Options ▸
StoreKit Configuration → select `Subscriptions.storekit`.

## Project layout
```
RoastMachine/
  RoastMachineApp.swift        app entry
  Models/AppConfig.swift       reads API keys from Info.plist
  Models/RoastMode.swift       personas + voices (free + premium)
  Services/RoastScriptService  OpenAI vision → roast text
  Services/VoiceService        ElevenLabs TTS + playback
  Services/RoastEngine         pipeline orchestrator
  Store/StoreManager           StoreKit 2 freemium
  Views/                       Home, Result, Paywall, pickers
```

## Content & App Store notes
- The system prompt frames every roast as a comedian practising on an *old photo
  of the user*, and forbids cruelty, protected characteristics, and profanity.
- Users only ever roast their own photos. Keep it that way for App Review.
- Both APIs are called directly from the client using the shipped keys — fine for
  an MVP/TestFlight, but move the calls behind a tiny backend proxy before a wide
  public launch so the keys aren't embedded in the binary.
