// Apple-signed proof, verified server-side:
//  - App Attest: attestation (one per install) and assertions (every request)
//    https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server
//  - StoreKit 2 signed transactions (JWS, x5c chain to Apple Root CA - G3)

import { decode as cborDecode } from "npm:cbor-x@1.6.0";
import * as x509 from "npm:@peculiar/x509@1.12.3";
import { p256 } from "npm:@noble/curves@1.6.0/p256";
import { p384 } from "npm:@noble/curves@1.6.0/p384";
import { sha256 as nobleSha256 } from "npm:@noble/hashes@1.5.0/sha256";
import { sha384 as nobleSha384 } from "npm:@noble/hashes@1.5.0/sha512";
import { APP_ATTEST_ROOT_B64, APPLE_ROOT_G3_B64 } from "./certs.ts";

// Signature checks use pure-JS @noble/curves: Apple's chains use P-384, which the
// Supabase Edge runtime's WebCrypto does not implement. @peculiar/x509 is used
// only to parse certificates.

x509.cryptoProvider.set(crypto);

export const TEAM_ID = "55Y3LX4J5J";
export const BUNDLE_ID = "AechTech.RoastMachine";
const APP_ID = `${TEAM_ID}.${BUNDLE_ID}`;

// ---------- bytes ----------

export const b64decode = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
export const b64encode = (b: Uint8Array) => {
  let s = "";
  for (const x of b) s += String.fromCharCode(x);
  return btoa(s);
};
const b64urlDecode = (s: string) =>
  b64decode(s.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(s.length / 4) * 4, "="));
const utf8 = (s: string) => new TextEncoder().encode(s);

/** Copy into a fresh ArrayBuffer-backed array, which WebCrypto's types require. */
const own = (b: Uint8Array) => new Uint8Array(b) as Uint8Array<ArrayBuffer>;

export async function sha256(data: Uint8Array): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", own(data)));
}
export function concat(...parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}
export function equal(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a[i] ^ b[i];
  return d === 0;
}

/** Verifies an ECDSA signature (DER or raw r||s) over `data`, hashing it first. */
export function ecdsaVerify(spki: Uint8Array, data: Uint8Array, signature: Uint8Array, hash: "SHA-256" | "SHA-384"): boolean {
  const digest = hash === "SHA-256" ? nobleSha256(data) : nobleSha384(data);
  // EC SubjectPublicKeyInfo ends with the uncompressed point (0x04 || X || Y).
  if (spki.length >= 97 && spki[spki.length - 97] === 0x04) {
    return p384.verify(signature, digest, spki.slice(spki.length - 97), { lowS: false });
  }
  if (spki.length >= 65 && spki[spki.length - 65] === 0x04) {
    return p256.verify(signature, digest, spki.slice(spki.length - 65), { lowS: false });
  }
  throw new Error("unsupported public key");
}

// ---------- minimal DER ----------

function tlv(buf: Uint8Array, at: number) {
  let len = buf[at + 1];
  let header = 2;
  if (len & 0x80) {
    const n = len & 0x7f;
    len = 0;
    for (let i = 0; i < n; i++) len = (len << 8) | buf[at + 2 + i];
    header = 2 + n;
  }
  return { tag: buf[at], start: at + header, end: at + header + len, whole: buf.slice(at, at + header + len) };
}

const OID_ECDSA_SHA256 = "2a8648ce3d040302";
const OID_ECDSA_SHA384 = "2a8648ce3d040303";
const hex = (b: Uint8Array) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");

/** Splits a certificate into the signed TBS bytes, hash algorithm and DER signature. */
function certSignatureParts(der: Uint8Array) {
  const cert = tlv(der, 0);
  const tbs = tlv(der, cert.start);
  const alg = tlv(der, tbs.end);
  const oid = tlv(der, alg.start);
  const sigBits = tlv(der, alg.end);
  const oidHex = hex(der.slice(oid.start, oid.end));
  const hash = oidHex === OID_ECDSA_SHA256 ? "SHA-256" : oidHex === OID_ECDSA_SHA384 ? "SHA-384" : null;
  if (!hash) throw new Error("unsupported certificate signature algorithm");
  // BIT STRING: first content byte is the unused-bits count (0).
  return { tbs: tbs.whole, hash: hash as "SHA-256" | "SHA-384", signature: der.slice(sigBits.start + 1, sigBits.end) };
}

/** True if `cert` was signed by `issuer`'s key. */
export function signedBy(cert: x509.X509Certificate, issuer: x509.X509Certificate): boolean {
  const parts = certSignatureParts(new Uint8Array(cert.rawData));
  return ecdsaVerify(new Uint8Array(issuer.publicKey.rawData), parts.tbs, parts.signature, parts.hash);
}

async function verifyChain(chain: x509.X509Certificate[], rootB64: string) {
  const root = new x509.X509Certificate(b64decode(rootB64));
  const top = chain[chain.length - 1];
  // The top of the presented chain is either Apple's root itself or signed by it.
  const anchored = equal(new Uint8Array(top.rawData), new Uint8Array(root.rawData))
    ? chain
    : [...chain, root];
  const now = new Date();
  for (let i = 0; i < anchored.length - 1; i++) {
    const cert = anchored[i];
    const issuer = anchored[i + 1];
    if (cert.issuer !== issuer.subject) throw new Error("certificate chain is out of order");
    if (now < cert.notBefore || now > cert.notAfter) throw new Error("certificate outside its validity period");
    if (!signedBy(cert, issuer)) throw new Error("certificate chain does not verify");
  }
  if (!equal(new Uint8Array(anchored[anchored.length - 1].rawData), new Uint8Array(root.rawData))) {
    throw new Error("chain is not anchored at the Apple root");
  }
}

// ---------- App Attest ----------

type AuthData = { rpIdHash: Uint8Array; counter: number; aaguid?: Uint8Array; credId?: Uint8Array };

function parseAuthData(a: Uint8Array): AuthData {
  const view = new DataView(a.buffer, a.byteOffset, a.byteLength);
  const out: AuthData = { rpIdHash: a.slice(0, 32), counter: view.getUint32(33) };
  if (a.length > 37) {
    out.aaguid = a.slice(37, 53);
    const len = view.getUint16(53);
    out.credId = a.slice(55, 55 + len);
  }
  return out;
}

const AAGUID_DEV = utf8("appattestdevelop");
const AAGUID_PROD = concat(utf8("appattest"), new Uint8Array(7));

/** Verifies a one-time attestation. Returns the key's SPKI to store. */
export async function verifyAttestation(
  keyIdB64: string,
  attestationB64: string,
  clientDataHash: Uint8Array,
): Promise<{ spki: Uint8Array; environment: "development" | "production" }> {
  const att = cborDecode(b64decode(attestationB64)) as {
    fmt: string;
    attStmt: { x5c: Uint8Array[] };
    authData: Uint8Array;
  };
  if (att.fmt !== "apple-appattest") throw new Error("not an App Attest attestation");

  const chain = att.attStmt.x5c.map((d) => new x509.X509Certificate(new Uint8Array(d)));
  await verifyChain(chain, APP_ATTEST_ROOT_B64);
  const cred = chain[0];

  const authData = new Uint8Array(att.authData);
  const nonce = await sha256(concat(authData, clientDataHash));
  const ext = cred.getExtension("1.2.840.113635.100.8.2");
  if (!ext) throw new Error("missing nonce extension");
  const extValue = new Uint8Array(ext.value);
  if (!equal(extValue.slice(extValue.length - 32), nonce)) throw new Error("nonce mismatch");

  const spki = new Uint8Array(cred.publicKey.rawData);
  const point = spki.slice(spki.length - 65); // uncompressed P-256 point
  const keyId = await sha256(point);
  if (!equal(keyId, b64decode(keyIdB64))) throw new Error("key id mismatch");

  const ad = parseAuthData(authData);
  if (!equal(ad.rpIdHash, await sha256(utf8(APP_ID)))) throw new Error("wrong app");
  if (ad.counter !== 0) throw new Error("attestation counter must be 0");
  if (!ad.credId || !equal(ad.credId, keyId)) throw new Error("credential id mismatch");
  let environment: "development" | "production";
  if (ad.aaguid && equal(ad.aaguid, AAGUID_PROD)) environment = "production";
  else if (ad.aaguid && equal(ad.aaguid, AAGUID_DEV)) environment = "development";
  else throw new Error("unknown App Attest environment");

  return { spki, environment };
}

/** Verifies a per-request assertion. Returns the new counter to store. */
export async function verifyAssertion(
  assertionB64: string,
  clientDataHash: Uint8Array,
  spki: Uint8Array,
  previousCounter: number,
): Promise<number> {
  const a = cborDecode(b64decode(assertionB64)) as {
    signature: Uint8Array;
    authenticatorData: Uint8Array;
  };
  const authData = new Uint8Array(a.authenticatorData);
  const nonce = await sha256(concat(authData, clientDataHash));
  const ok = ecdsaVerify(spki, nonce, new Uint8Array(a.signature), "SHA-256");
  if (!ok) throw new Error("bad assertion signature");

  const ad = parseAuthData(authData);
  if (!equal(ad.rpIdHash, await sha256(utf8(APP_ID)))) throw new Error("wrong app");
  if (ad.counter <= previousCounter) throw new Error("replayed assertion");
  return ad.counter;
}

// ---------- StoreKit 2 ----------

export type SignedTransaction = {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  type: string;
  environment: string;
  appAccountToken?: string;
  revocationDate?: number;
};

/** Verifies a StoreKit 2 JWS transaction and returns its payload. */
export async function verifyTransaction(jws: string): Promise<SignedTransaction> {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("malformed JWS");
  const [h, p, s] = parts;
  const header = JSON.parse(new TextDecoder().decode(b64urlDecode(h)));
  if (header.alg !== "ES256" || !Array.isArray(header.x5c)) throw new Error("unexpected JWS header");

  const chain = (header.x5c as string[]).map((c) => new x509.X509Certificate(b64decode(c)));
  await verifyChain(chain, APPLE_ROOT_G3_B64);
  if (!chain[0].getExtension("1.2.840.113635.100.6.11.1")) throw new Error("leaf is not an App Store receipt signer");
  if (chain.length > 1 && !chain[1].getExtension("1.2.840.113635.100.6.2.1")) throw new Error("unexpected intermediate");

  const ok = ecdsaVerify(new Uint8Array(chain[0].publicKey.rawData), utf8(`${h}.${p}`), b64urlDecode(s), "SHA-256");
  if (!ok) throw new Error("bad JWS signature");

  return JSON.parse(new TextDecoder().decode(b64urlDecode(p))) as SignedTransaction;
}
