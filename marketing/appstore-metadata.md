# Roast Machine — App Store Connect metadata

Copy-paste source for the App Store listing. Keep in sync with the app.

## App

| Field | Value |
|---|---|
| Name | Roast Machine |
| Subtitle (≤30) | AI comedians roast your photo |
| Bundle ID | AechTech.RoastMachine |
| SKU | roastmachine-ios |
| Primary category | Entertainment |
| Secondary category | Photo & Video |
| Age rating | Answer the questionnaire: Infrequent/Mild Profanity or Crude Humor = Infrequent; everything else None (lands at 9+ or 13+ under the 2025 tiers) |
| Copyright | 2026 AechTech |
| Support URL | https://pbakerx.github.io/roast_machine/ |
| Privacy Policy URL | https://pbakerx.github.io/roast_machine/privacy.html |
| Price | Free (with one in-app purchase) |

## Promotional text (≤170)

Your first roast and your first hype are on the house. One payment unlocks all 14 comedians, forever.

## Description

Point the camera at your face. Pick a comedian. Get roasted — out loud.

Roast Machine is a stand-up act in your pocket. Snap a photo (or grab one from your library), spin the dial to one of 14 AI comedians, and hit the big button. Seconds later a real voice is ripping into your outfit, your hair, your pose, your whole vibe.

Feeling fragile? Flip the switch to HYPE and the same comedians go the other way: over-the-top, no-notes, you-are-a-legend compliments. Same voices. All love.

THE LINEUP
• Classic Roast — a late-night headliner works the crowd
• Angry Chef — this face is RAW
• Disappointed Mom — "I'm not mad."
• Shakespearean — thou art absurd
• Nature Documentary — a rare specimen in its habitat
• Diss Track, Drill Sergeant, Corporate Influencer, Conspiracy Theorist, Fortune Teller, Pickup Lines, Dating Bio, Pet Translator, and You're So Beautiful

BUILT FOR THE GROUP CHAT
Every bit exports as a video with the audio baked in. One tap to share.

THE DEAL
Your first roast and your first hype are free. After that, one $2.99 payment unlocks every comedian and unlimited roasts and hype — forever. No subscription. No credits. No nonsense.

PLAY NICE
Before the first show the app asks your permission and tells you exactly where your photo goes. Every bit is written by an AI comedian playing a character, with guardrails: it only riffs on what's in the picture — never on who you are. Roast yourself, or friends who are in on the joke.

## Keywords (≤100 chars)

roast,comedy,funny,joke,ai,voice,photo,compliment,hype,humor,party,selfie,prank,burn,standup

## What's New (1.0)

The machine is open. 14 comedians, one big button, and a HYPE switch for when you need it.

## App Privacy (nutrition label)

- Data collected: **Photos or Videos** — used for App Functionality; **not** linked to the user; **not** used for tracking.
- Nothing else. No identifiers, no usage data, no diagnostics, no contact info.
- Third-party AI: Yes — OpenAI (photo + text) and ElevenLabs (text). Disclosed in the privacy policy.

## In-App Purchase

| Field | Value |
|---|---|
| Type | Non-Consumable |
| Reference name | Everything Unlock |
| Product ID | AechTech.RoastMachine.allmodes |
| Price | $2.99 (Tier 3) |
| Display name | Everything |
| Description | Unlimited roasts and hype from every comedian. One payment, forever. |
| Review screenshot | marketing/screenshots/iap_paywall.png |

## App Review notes

Roast Machine generates short comedy bits about a photo the user supplies, using OpenAI (GPT-4o vision) to write the script and ElevenLabs to voice it. Every request carries guardrails (only what's visible in the picture; never protected characteristics, weight, or disability; profanity capped at "damn"). Nothing is stored server-side by us.

To test: allow the camera (or tap Photo and pick any picture of a person), leave the dial on Classic Roast, and press the big flame button. A one-time "Before the Show" sheet discloses that the photo is sent to OpenAI and the text to ElevenLabs and asks for permission (guideline 5.1.2(i)); tap LET'S GO. Flip the ROAST/HYPE switch to hear the compliment version. Each install gets one free roast and one free hype; a third press opens the $2.99 "Everything" purchase, which can be exercised with a sandbox account. Restore Purchases is on the same screen.

No login is required. The app is iPhone-only, portrait-only.
