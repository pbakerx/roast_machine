import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import * as x509 from "npm:@peculiar/x509@1.12.3";
import { b64decode, ecdsaVerify, signedBy, verifyAssertion, verifyAttestation, verifyTransaction } from "./apple.ts";
import { APP_ATTEST_ROOT_B64, APPLE_ROOT_G3_B64 } from "./certs.ts";
import { PERSONAS, PRODUCTS, systemPrompt } from "./personas.ts";

Deno.test("Apple's P-384 roots verify their own signatures", () => {
  for (const b64 of [APP_ATTEST_ROOT_B64, APPLE_ROOT_G3_B64]) {
    const root = new x509.X509Certificate(b64decode(b64));
    assert(signedBy(root, root));
  }
  const attest = new x509.X509Certificate(b64decode(APP_ATTEST_ROOT_B64));
  const g3 = new x509.X509Certificate(b64decode(APPLE_ROOT_G3_B64));
  assert(!signedBy(attest, g3), "a cert must not verify under the wrong key");
});

Deno.test("ecdsaVerify: P-256 and P-384, DER and raw signatures", async () => {
  const data = new TextEncoder().encode("roast machine");
  for (const [curve, hash] of [["P-256", "SHA-256"], ["P-384", "SHA-384"]] as const) {
    const key = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: curve }, true, ["sign", "verify"]);
    const spki = new Uint8Array(await crypto.subtle.exportKey("spki", key.publicKey));
    const raw = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash }, key.privateKey, data));
    assert(ecdsaVerify(spki, data, raw, hash), `${curve} raw`);
    assert(!ecdsaVerify(spki, new TextEncoder().encode("tampered"), raw, hash), `${curve} tamper`);
  }
});

Deno.test("every comedian has a voice and a prompt, for both flavors", () => {
  const ids = ["classic","nature","ramsay","mom","shakespeare","disstrack","beautiful","fortune",
               "drill","linkedin","conspiracy","pickup","datingbio","pet"];
  assertEquals(Object.keys(PERSONAS).sort(), [...ids].sort());
  for (const id of ids) {
    assert(systemPrompt(id, "roast").includes("PERSONA:"));
    assert(systemPrompt(id, "compliment").includes("HYPE"));
  }
});

Deno.test("ticket packs", () => {
  assertEquals(PRODUCTS["AechTech.RoastMachine.tickets20"], 20);
  assertEquals(Object.keys(PRODUCTS).length, 3);
});

Deno.test("forged StoreKit transactions are rejected", async () => {
  const fakeHeader = btoa(JSON.stringify({ alg: "ES256", x5c: [] })).replace(/=+$/, "");
  const fakePayload = btoa(JSON.stringify({ productId: "AechTech.RoastMachine.tickets60" })).replace(/=+$/, "");
  await assertRejects(() => verifyTransaction(`${fakeHeader}.${fakePayload}.AAAA`));
  await assertRejects(() => verifyTransaction("not-a-jws"));
});

Deno.test("garbage attestations and assertions are rejected", async () => {
  await assertRejects(() => verifyAttestation("AAAA", "oA==", new Uint8Array(32)));
  const key = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const spki = new Uint8Array(await crypto.subtle.exportKey("spki", key.publicKey));
  await assertRejects(() => verifyAssertion("oA==", new Uint8Array(32), spki, 0));
});
