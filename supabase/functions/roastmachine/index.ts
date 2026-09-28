// Roast Machine backend. One function, routed by path:
//   POST /roastmachine/challenge   -> one-time App Attest challenge
//   POST /roastmachine/register    -> verify attestation, bind key to wallet
//   POST /roastmachine/wallet      -> ticket balance            (asserted)
//   POST /roastmachine/show        -> spend + write the bit     (asserted)
//   POST /roastmachine/voice       -> voice a written bit       (asserted)
//   POST /roastmachine/credit      -> credit a verified purchase (asserted)
//
// Asserted routes need headers x-rm-key (App Attest key id) and x-rm-assertion,
// signed over SHA-256 of the exact request body. The API keys for OpenAI and
// ElevenLabs never leave this function.

import postgres from "npm:postgres@3.4.5";
import {
  b64decode, b64encode, BUNDLE_ID, sha256, verifyAssertion, verifyAttestation, verifyTransaction,
} from "../_shared/apple.ts";
import { cleanScript, FALLBACK_VOICES, type Flavor, PERSONAS, PRODUCTS, systemPrompt, userPrompt, voiceFor } from "../_shared/personas.ts";

const env = (k: string, fallback = "") => Deno.env.get(k) ?? fallback;
const sql = postgres(env("SUPABASE_DB_URL"), { prepare: false, max: 3 });

const DAILY_CAP = Number(env("ROASTMACHINE_DAILY_CAP", "30"));
const IP_HOURLY_CAP = Number(env("ROASTMACHINE_IP_HOURLY_CAP", "40"));
const GLOBAL_DAILY_CAP = Number(env("ROASTMACHINE_GLOBAL_DAILY_CAP", "3000"));
const MAX_IMAGE_BYTES = 1_500_000;

class HttpError extends Error {
  constructor(public status: number, public code: string, message?: string) {
    super(message ?? code);
  }
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

async function ipHash(req: Request): Promise<string> {
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim();
  if (!ip) return "";
  const salt = env("ROASTMACHINE_IP_SALT");
  return b64encode(await sha256(new TextEncoder().encode(`${salt}:${ip}`))).slice(0, 24);
}

// ---------- caller identity ----------

type Caller = { walletId: string; dev: boolean };

async function authenticate(req: Request, body: Uint8Array): Promise<Caller> {
  // Development bypass for the simulator (which cannot do App Attest). Only
  // active while the ROASTMACHINE_DEV_TOKEN secret exists; delete it to close.
  const devToken = env("ROASTMACHINE_DEV_TOKEN");
  const presented = req.headers.get("x-rm-dev");
  if (devToken && presented && presented === devToken) {
    const walletId = req.headers.get("x-rm-wallet") ?? "";
    if (!/^[0-9a-f-]{36}$/i.test(walletId)) throw new HttpError(400, "bad_wallet");
    await sql`insert into app_roastmachine.wallets (id) values (${walletId}) on conflict (id) do nothing`;
    return { walletId, dev: true };
  }

  const keyId = req.headers.get("x-rm-key");
  const assertion = req.headers.get("x-rm-assertion");
  if (!keyId || !assertion) throw new HttpError(401, "unattested");

  const [key] = await sql`
    select wallet_id, public_key, counter from app_roastmachine.attest_keys where key_id = ${keyId}`;
  if (!key) throw new HttpError(401, "unknown_key");
  let counter: number;
  try {
    counter = await verifyAssertion(assertion, await sha256(body), new Uint8Array(key.public_key), Number(key.counter));
  } catch (e) {
    throw new HttpError(401, "bad_assertion", String(e));
  }
  const updated = await sql`
    update app_roastmachine.attest_keys set counter = ${counter}, last_seen_at = now()
    where key_id = ${keyId} and counter < ${counter} returning key_id`;
  if (updated.length === 0) throw new HttpError(401, "replayed_assertion");
  return { walletId: key.wallet_id, dev: false };
}

// ---------- routes ----------

async function challenge(): Promise<Response> {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const [row] = await sql`
    insert into app_roastmachine.challenges (challenge) values (${bytes}) returning id`;
  await sql`delete from app_roastmachine.challenges where created_at < now() - interval '1 day'`;
  return json({ challengeId: row.id, challenge: b64encode(bytes) });
}

async function register(body: Record<string, string>): Promise<Response> {
  const { challengeId, keyId, attestation, walletId } = body;
  if (!challengeId || !keyId || !attestation || !/^[0-9a-f-]{36}$/i.test(walletId ?? "")) {
    throw new HttpError(400, "bad_request");
  }
  const [ch] = await sql`
    update app_roastmachine.challenges set used_at = now()
    where id = ${challengeId} and used_at is null and created_at > now() - interval '5 minutes'
    returning challenge`;
  if (!ch) throw new HttpError(400, "stale_challenge");

  let verified;
  try {
    verified = await verifyAttestation(keyId, attestation, await sha256(new Uint8Array(ch.challenge)));
  } catch (e) {
    throw new HttpError(401, "bad_attestation", String(e));
  }
  await sql.begin(async (tx) => {
    await tx`insert into app_roastmachine.wallets (id) values (${walletId}) on conflict (id) do nothing`;
    await tx`
      insert into app_roastmachine.attest_keys (key_id, wallet_id, public_key, environment)
      values (${keyId}, ${walletId}, ${verified.spki}, ${verified.environment})
      on conflict (key_id) do nothing`;
  });
  const [w] = await sql`select app_roastmachine.wallet_json(${walletId}) as w`;
  return json({ wallet: w.w });
}

async function wallet(caller: Caller): Promise<Response> {
  const [w] = await sql`select app_roastmachine.wallet_json(${caller.walletId}) as w`;
  return json({ wallet: w.w });
}

async function show(req: Request, caller: Caller, body: Record<string, string>): Promise<Response> {
  const { modeId, flavor, image } = body;
  if (!PERSONAS[modeId]) throw new HttpError(400, "unknown_mode");
  if (flavor !== "roast" && flavor !== "compliment") throw new HttpError(400, "bad_flavor");
  if (!image || image.length * 0.75 > MAX_IMAGE_BYTES) throw new HttpError(400, "bad_image");

  const [spent] = await sql`
    select app_roastmachine.spend_show(${caller.walletId}, ${modeId}, ${flavor}, ${await ipHash(req)},
      ${caller.dev}, ${DAILY_CAP}, ${IP_HOURLY_CAP}, ${GLOBAL_DAILY_CAP}) as r`;
  const r = spent.r;
  if (!r.ok) return json({ error: r.reason, wallet: r.wallet ?? null }, r.reason === "no_tickets" ? 402 : 429);

  try {
    const script = await writeBit(modeId, flavor, image);
    await sql`update app_roastmachine.shows set script = ${script}, script_chars = ${script.length} where id = ${r.show_id}`;
    return json({ showId: r.show_id, script, wallet: r.wallet });
  } catch (e) {
    const [refund] = await sql`select app_roastmachine.refund_show(${r.show_id}) as w`;
    console.error("show failed", e);
    return json({ error: "writer_failed", wallet: refund.w }, 502);
  }
}

async function voice(caller: Caller, body: Record<string, string>): Promise<Response> {
  const { showId, voice: voiceKey } = body;
  if (!/^[0-9a-f-]{36}$/i.test(showId ?? "")) throw new HttpError(400, "bad_request");
  const [s] = await sql`
    select flavor, script from app_roastmachine.shows
    where id = ${showId} and wallet_id = ${caller.walletId} and voiced_at is null
      and refunded_at is null and script is not null and created_at > now() - interval '10 minutes'`;
  if (!s) throw new HttpError(404, "no_such_show");

  const flavor = s.flavor as Flavor;
  const voiceId = voiceFor(flavor, voiceKey);
  let res = await speak(voiceId, s.script);
  if ([401, 403, 404].includes(res.status)) {
    // The chosen library voice was disabled or removed; don't fail the show.
    console.error("voice unavailable, using fallback", voiceId, res.status, (await res.text()).slice(0, 200));
    res = await speak(FALLBACK_VOICES[flavor], s.script);
  }
  if (!res.ok) {
    console.error("elevenlabs", res.status, (await res.text()).slice(0, 300));
    const [refund] = await sql`select app_roastmachine.refund_show(${showId}) as w`;
    return json({ error: "voice_failed", wallet: refund.w }, 502);
  }
  const audio = new Uint8Array(await res.arrayBuffer());
  await sql`update app_roastmachine.shows set voiced_at = now(), script = null where id = ${showId}`;
  return new Response(audio, { headers: { "content-type": "audio/mpeg" } });
}

function speak(voiceId: string, text: string): Promise<Response> {
  return fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`, {
    method: "POST",
    headers: {
      "xi-api-key": env("ROASTMACHINE_ELEVENLABS_API_KEY"),
      "content-type": "application/json",
      accept: "audio/mpeg",
    },
    body: JSON.stringify({
      text,
      model_id: "eleven_multilingual_v2",
      voice_settings: { stability: 0.4, similarity_boost: 0.75, style: 0.6, use_speaker_boost: true },
    }),
  });
}

async function credit(caller: Caller, body: Record<string, string>): Promise<Response> {
  let tx;
  try {
    tx = await verifyTransaction(body.jws ?? "");
  } catch (e) {
    throw new HttpError(400, "bad_transaction", String(e));
  }
  if (tx.bundleId !== BUNDLE_ID) throw new HttpError(400, "wrong_bundle");
  const tickets = PRODUCTS[tx.productId];
  if (!tickets || tx.type !== "Consumable") throw new HttpError(400, "unknown_product");
  if (tx.revocationDate) throw new HttpError(400, "revoked");
  if ((tx.appAccountToken ?? "").toLowerCase() !== caller.walletId.toLowerCase()) {
    throw new HttpError(403, "wrong_wallet");
  }
  const [c] = await sql`
    select app_roastmachine.credit_purchase(${tx.transactionId}, ${caller.walletId}, ${tx.productId},
      ${tickets}, ${tx.environment}) as r`;
  return json(c.r);
}

// ---------- the writer ----------

async function writeBit(modeId: string, flavor: Flavor, imageB64: string): Promise<string> {
  // One retry covers the occasional bare "I don't know who this is" reply.
  for (let attempt = 0; attempt < 2; attempt++) {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        authorization: `Bearer ${env("ROASTMACHINE_OPENAI_API_KEY")}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o",
        max_tokens: 160,
        temperature: 0.9,
        messages: [
          { role: "system", content: systemPrompt(modeId, flavor) },
          {
            role: "user",
            content: [
              { type: "text", text: userPrompt(flavor) },
              { type: "image_url", image_url: { url: `data:image/jpeg;base64,${imageB64}`, detail: "low" } },
            ],
          },
        ],
      }),
    });
    if (!res.ok) throw new Error(`openai ${res.status}: ${(await res.text()).slice(0, 300)}`);
    const data = await res.json();
    const text = cleanScript(data.choices?.[0]?.message?.content ?? "");
    if (text) return text;
  }
  throw new Error("no usable script");
}

// ---------- entry ----------

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") throw new HttpError(405, "method_not_allowed");
    const route = new URL(req.url).pathname.split("/").pop();
    const raw = new Uint8Array(await req.arrayBuffer());
    const body = raw.length ? JSON.parse(new TextDecoder().decode(raw)) : {};

    switch (route) {
      case "challenge": return await challenge();
      case "register": return await register(body);
    }
    const caller = await authenticate(req, raw);
    switch (route) {
      case "wallet": return await wallet(caller);
      case "show": return await show(req, caller, body);
      case "voice": return await voice(caller, body);
      case "credit": return await credit(caller, body);
    }
    throw new HttpError(404, "not_found");
  } catch (e) {
    if (e instanceof HttpError) {
      if (e.status >= 500 || e.status === 401) console.error(e.code, e.message);
      return json({ error: e.code }, e.status);
    }
    console.error("unhandled", e);
    return json({ error: "server_error" }, 500);
  }
});
