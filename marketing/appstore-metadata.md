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

Your first roast and your first hype are on the house. Then grab a pack of shows — 20 for $3.99, and they never expire.

## Description

Point the camera at your face. Pick a comedian. Get roasted — out loud.

Roast Machine is a stand-up act in your pocket. Snap a photo (or grab one from your library), spin the dial to one of 14 AI comedians, and hit the big button. Seconds later a real voice is ripping into your outfit, your hair, your pose, your whole vibe.

Feeling fragile? Flip the switch to HYPE and the same comedians go the other way: over-the-top, crown-on-your-head, you-are-a-legend compliments. All love.

PICK YOUR VOICE
Choose who delivers the bit: a hype man, a buzzing bee, a salty pirate, a cheeky Cockney, a gravelly cowboy, and more. Set one voice for roasts and another for hype.

THE LINEUP
• Classic Roast — a late-night headliner works the crowd
• Angry Chef — this face is RAW
• Disappointed Mom — "I'm not mad."
• Shakespearean — thou art absurd
• Nature Documentary — a rare specimen in its habitat
• Diss Track, Drill Sergeant, Corporate Influencer, Conspiracy Theorist, Fortune Teller, Pickup Lines, Dating Bio, Pet Translator, and You're So Beautiful

BUILT FOR THE GROUP CHAT
Every bit exports as a video with the audio baked in. One tap to share.

THE BOX OFFICE
Your first roast and your first hype are free. After that, each show is one ticket:
• Top-Up — 8 shows for $1.99
• Opening Act — 20 shows for $3.99
• Headliner — 60 shows for $9.99
One ticket = one roast or one hype, with any comedian and any voice. Run out and the comedian will let you know. Loudly. Replays and shares are free, tickets never expire, and there's no subscription.

PLAY NICE
Before the first show the app asks your permission and tells you exactly where your photo goes. Every bit is written by an AI comedian playing a character, with guardrails: it only riffs on what's in the picture — never on who you are. Roast yourself, or friends who are in on the joke.

## Keywords (≤100 chars)

funny,comedy,joke,laugh,meme,insult,compliment,hype,selfie,face,voice,prank,humor,standup,burn

The name and subtitle already index "roast", "AI", "comedians" and "photo", so the keywords skip them.

## What's New (1.0)

The machine is open. 14 comedians, 8 voices, one big button, and a HYPE switch for when you need it.

## App Privacy (nutrition label)

All "App Functionality", **not linked** to the user, **not** used for tracking:
- **User Content → Photos or Videos** — the photo passes through our server to OpenAI; never stored.
- **Identifiers → User ID** — the random wallet ID that holds ticket balances.
- **Purchases → Purchase History** — App Store transaction IDs, to credit tickets once.

Nothing else: no contact info, location, usage data, diagnostics or advertising ID.
Third-party AI: OpenAI (photo + text) and ElevenLabs (text), via our server.

## In-App Purchases (consumable ticket packs)

| Reference name | Product ID | Price | Display name | Description |
|---|---|---|---|---|
| Top-Up 8 Shows | AechTech.RoastMachine.tickets8 | $1.99 | Top-Up: 8 Shows | 8 tickets. 1 ticket = 1 roast or 1 hype. |
| Opening Act 20 Shows | AechTech.RoastMachine.tickets20 | $3.99 | Opening Act: 20 Shows | 20 tickets. 1 ticket = 1 roast or 1 hype. |
| Headliner 60 Shows | AechTech.RoastMachine.tickets60 | $9.99 | Headliner: 60 Shows | 60 tickets. 1 ticket = 1 roast or 1 hype. |

Review screenshot: `marketing/screenshots/iap_boxoffice.png`. The old non-consumable
"Everything Unlock" (`AechTech.RoastMachine.allmodes`) is an unsubmitted draft and unused.

## App Review notes

Roast Machine generates short comedy bits about a photo the user supplies. Our server (Supabase) sends the photo to OpenAI (GPT-4o vision) to write the script and the text to ElevenLabs to voice it; the app itself holds no API keys. Every request carries guardrails (only what's visible in the picture; never protected characteristics, weight, or disability; profanity capped at "damn"). Photos are never stored.

To test: allow the camera (or tap Photo and pick any picture of a person), leave the dial on Classic Roast, and press the big flame button. A one-time "Before the Show" sheet discloses that the photo is sent to OpenAI and the text to ElevenLabs and asks for permission (guideline 5.1.2(i)); tap LET'S GO. Flip the ROAST/HYPE switch for the compliment version.

Each device gets one free roast and one free hype. After that the shutter opens the Box Office, which sells consumable ticket packs (8/$1.99, 20/$3.99, 60/$9.99); one ticket = one show. Purchases can be exercised with a sandbox account; tickets are credited by our server after it verifies Apple's signed transaction.

Requests are authenticated with Apple App Attest, so please test on a physical device (the Simulator does not support App Attest). No login is required. The app is iPhone-only, portrait-only.
