# Hashes, keys, tokens and certificates: the code

The programs behind the slides, for Jennifer 0.26.0. Most use only the
`hash` and `crypto` libraries and the bundled `totp`, `jwt`, `oauth` and
`acme` modules. `seal.j` uses the `@deckyard/sealbox` deck listed in
`deck.toml`: run `jvc install` once in this folder to fill `vendor/`. Run
everything from this folder. Every key and secret is a placeholder or is
generated fresh on each run.

- `hashmac.j`: a SHA-256 digest, an HMAC over a webhook body and a constant
  time comparison ("Hash, MAC, and a comparison that does not leak").
  Run: `jennifer run hashmac.j`
- `encrypt.j`: XChaCha20-Poly1305 with a fresh nonce, a tampered box, an
  Ed25519 signature ("Encryption is authenticated, signatures are public").
  Run: `jennifer run encrypt.j`
- `passwords.j`: argon2id hashing, timing and verification ("Passwords:
  argon2id, never a digest"). Run: `jennifer run passwords.j`
- `enrol.j`: a TOTP secret, its `otpauth://` URI and a QR code written to
  `enrol.png` ("TOTP: enrolment is a URI and a QR code").
  Run: `jennifer run enrol.j`
- `verify2fa.j`: a +/-1 step window and refusing a code a second time ("TOTP:
  a window, and no second use"). Run: `jennifer run verify2fa.j`
- `jwt1.j`: sign with Ed25519, then `verifyWith` a policy ("JWT: sign, then
  verify against a policy"). Run: `jennifer run jwt1.j`
- `jwt2.j`: `alg: none`, algorithm confusion, a tampered token, all refused
  ("JWT: what `verifyWith` refuses"). Run: `jennifer run jwt2.j`
- `misuse.j`: the `"value"` errors of `jwt` and `totp` for bad parameters
  ("Errors and their kinds"). Run: `jennifer run misuse.j`
- `authsrv.j`: a fake OAuth2 authorization server on `127.0.0.1:9400`,
  client credentials and authorization code with PKCE, rotating refresh
  tokens. It stands in for a real identity provider.
  Run: `jennifer run authsrv.j &`
- `cc.j`: the client credentials grant, and a wrong secret as an
  `OAuthError` ("OAuth2: a service as itself"). With `authsrv.j` running:
  `SHELF_CLIENT_SECRET=PLACEHOLDER-client-secret jennifer run cc.j`
- `pkce.j`: authorization code with PKCE and a loopback redirect, refresh,
  reuse of an old refresh token refused, the token saved to `token.json`
  ("OAuth2: authorization code with PKCE", "OAuth2: refresh, rotation, and
  the token file"). With `authsrv.j` running: `jennifer run pkce.j`
- `acme1.j`: account, order, HTTP-01 challenge served on `127.0.0.1:5002`,
  finalize, and `cert.pem` / `key.pem` written owner-only ("ACME: account,
  order, challenge", "ACME: prove it, check it, finalize"). It creates its
  account key `account.pem` on the first run. Needs pebble, see below:
  `SSL_CERT_FILE=pebble/pebble-root.pem jennifer run acme1.j`
- `acme_wrong.j`: the same program serving a wrong answer, ending in
  `authorization invalid` ("ACME: prove it, check it, finalize").
  Run like `acme1.j`.
- `renew.j`: reads the validity dates of `cert.pem` with `asn1` and says when
  to renew ("When to renew"). Run after `acme1.j`: `jennifer run renew.j`
- `seal.j`: seal and open a secret bound to a row id with
  `@deckyard/sealbox` ("Sealed secrets with `@deckyard/sealbox`").
  Run: `jvc install`, then `jennifer run seal.j`
- `keys.j`: an owner-only key file check and key rotation by `kid` ("Keys:
  owner-only files, ids, rotation"). `make-keys.sh` writes the two
  placeholder keys into `keys/`, the newer one readable by others on purpose.
  Run: `./make-keys.sh`, then `SHELF_KEY_DIR=keys jennifer run keys.j`

## pebble, the test CA

`pebble/start.sh` starts Let's Encrypt's test CA pebble 2.8.0 with
`pebble/pebble-config.json` (directory on `127.0.0.1:14000`, HTTP-01
challenges to port 5002, ninety-day certificates) and
`pebble-challtestsrv` as its DNS server, which answers `127.0.0.1` for
`shelf.example.test`. Both containers use host networking, because pebble
must reach the challenge server on the host's loopback. The script also
downloads pebble's throwaway test root into `pebble/pebble-root.pem` for
`SSL_CERT_FILE`. Stop with
`docker rm -f academy-crypto-pebble academy-crypto-dns`.
No certificate or key file is shipped here; `acme1.j` creates its own.
