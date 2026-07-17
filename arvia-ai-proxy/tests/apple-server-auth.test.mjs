import assert from "node:assert/strict";
import test from "node:test";

function bytesToPEM(bytes) {
  const base64 = Buffer.from(bytes).toString("base64");
  const lines = base64.match(/.{1,64}/g) ?? [];
  return `-----BEGIN PRIVATE KEY-----\n${lines.join("\n")}\n-----END PRIVATE KEY-----`;
}

test("App Store Server JWT uses the configured ES256 key and claims", async () => {
  const keyPair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const privateKey = await crypto.subtle.exportKey("pkcs8", keyPair.privateKey);

  process.env.ARVIA_IAP_ISSUER_ID = "test-issuer";
  process.env.ARVIA_IAP_KEY_ID = "TESTKEY123";
  process.env.ARVIA_IAP_PRIVATE_KEY = bytesToPEM(privateKey);
  process.env.ARVIA_BUNDLE_ID = "com.ruhsatim.app";

  const { createAppleServerJWT, decodeBase64URLJSON } = await import("../api/complete.ts");
  const token = await createAppleServerJWT();
  const [encodedHeader, encodedPayload, encodedSignature] = token.split(".");

  assert.deepEqual(decodeBase64URLJSON(encodedHeader), {
    alg: "ES256",
    kid: "TESTKEY123",
    typ: "JWT",
  });
  const payload = decodeBase64URLJSON(encodedPayload);
  assert.equal(payload.iss, "test-issuer");
  assert.equal(payload.aud, "appstoreconnect-v1");
  assert.equal(payload.bid, "com.ruhsatim.app");
  assert.ok(payload.exp > payload.iat);
  assert.ok(payload.exp - payload.iat <= 300);

  const signature = Buffer.from(encodedSignature, "base64url");
  const verified = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    keyPair.publicKey,
    signature,
    new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`),
  );
  assert.equal(verified, true);
});
