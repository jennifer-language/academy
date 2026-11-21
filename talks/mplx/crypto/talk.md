---
theme: obsidian
mode: dark
ratio: 16:9
transition: slide
---

# Crypto, tokens and certificates with Jennifer

![Jennifer](jennifer-logo.png)

Hashes, MACs, ciphers and signatures, passwords, two-factor codes, JWT,
OAuth2, ACME certificates and sealed secrets.

Based on **Jennifer 0.26.0**, November 2026, by [@mplx](https://github.com/mplx).

<!-- notes:
This talk is for people who already write services in Jennifer and now have
to log users in, sign tokens, call an API with OAuth2 or get a certificate.
It walks from the primitives in the hash and crypto libraries up to the
bundled totp, jwt, oauth and acme modules and the sealbox deck. Every output
was produced with the released Jennifer 0.26.0 and its modules: OAuth2
against a small fake authorization server written in Jennifer, ACME against
Let's Encrypt's test CA pebble in a container, both on 127.0.0.1. Every key
and secret shown is a placeholder or a throwaway from a demo run.
-->

---

## Four tools, four questions

| Tool | Answers | Key | Jennifer |
| --- | --- | --- | --- |
| Hash | Is this the same data? | none | `hash.compute("sha256", b)` |
| MAC | Did someone with our key send it? | shared secret | `hash.hmac("sha256", b, key)` |
| Encryption | Can only key holders read it? | shared secret | `crypto.encrypt(algo, ...)` |
| Signature | Did the private key's owner write it? | key pair | `crypto.sign(algo, ...)` |

A hash proves nothing about who; encryption alone proves nothing about
what. The algorithm is always the first argument.

<!-- notes:
Most crypto bugs are the wrong tool for the question. A bare SHA-256 of a
message can be recomputed by anyone who changes the message, so it is no
authentication. A MAC needs both sides to share a secret, and a signature
lets anyone check without being able to sign. Jennifer has one function per
operation with the algorithm as a string, so a negotiated algorithm is a
variable and an unknown name is an error listing the known ones. Digests and
HMAC live in hash, everything that needs secure randomness lives in crypto.
None of it is hand-rolled: it is Go's standard library and golang.org/x/crypto,
randomness comes from the operating system, and comparisons use Go's
constant-time compare. The library pages list every default.
-->

---

## Hash, MAC, and a comparison that does not leak

```jennifer excerpt
def body as bytes init convert.bytesFromString("utf-8", '{"order":42}');
def key as bytes init
    convert.bytesFromString("utf-8", "PLACEHOLDER-hook-key");
def mac as string init
    encoding.toText("hex", hash.hmac("sha256", $body, $key));
func authentic(body as bytes, sent as string, key as bytes) {
    def want as bytes init hash.hmac("sha256", $body, $key);
    return hash.equal($want, encoding.fromText("hex", $sent));
}
```

```text
sha256 54985dc3c12fada7a1b1db53...
hmac   d3d0fb779cbe4a0a18d06324...
true false
```

<!-- notes:
This is how you check a webhook: recompute the MAC over the raw body you
received and compare it with the one in the header. hash.equal takes the same
time wherever the first difference is. A plain == stops at the first wrong
byte, and over many requests that timing tells an attacker how much of a
forged MAC is already right. The second call passes 64 zeros. A header that is
not hex at all makes encoding.fromText throw, which a real handler catches and
answers with 401. The printing lines are left out here.
-->

---

## Encryption is authenticated, signatures are public

```jennifer excerpt
def nonce as bytes init crypto.randBytes(24);          # never reuse one
def box as bytes init crypto.encrypt("xchacha20-poly1305", $msg,
    $key, $nonce, $none);
$box[0] = $box[0] ^ 1;                                 # flip one bit
crypto.decrypt("xchacha20-poly1305", $box, $key, $nonce, $none);
def kp as crypto.Keypair init crypto.keypair("ed25519");
def sig as bytes init crypto.sign("ed25519", $msg, $kp.private);
crypto.verify("ed25519", $forged, $sig, $kp.public);
```

```text
runtime | crypto.decrypt: authentication failed (wrong key,
  nonce or aad, or tampered data)
sig: 64 bytes, ok true
forged: false
```

<!-- notes:
The three ciphers behind crypto.encrypt are AEAD: the box carries a 16-byte
tag, and one changed bit makes decrypt fail instead of returning garbage. The
key is 32 random bytes; the 24-byte nonce of XChaCha20 is safe to draw at
random for every message, and a nonce must never repeat under one key. The
error is kind runtime and says nothing about which part was wrong. Ed25519
signatures are 64 bytes; verify returns false for a forged message and only
throws for a malformed key. The try blocks and prints are left out, and
the error line is wrapped here.
-->

---

## Passwords: argon2id, never a digest

```jennifer excerpt
def stored as string init
    crypto.hashPassword("argon2id", "correct horse battery");
crypto.verifyPassword("Correct horse battery", $stored);

# on login: an old bcrypt hash that verified is replaced
if (crypto.verifyPassword($pw, $old) and
    strings.startsWith($old, "$2")) {
    $old = crypto.hashPassword("argon2id", $pw);
}
```

```text
$argon2id$v=19$m=65536,t=3,p=4$xQdPRU0FpHz0P7muZEnyiQ$B+JOjH... (61 ms)
false
now $argon2id$v=19$m=65536,t=3,p=4...
```

<!-- notes:
crypto.hashPassword picks a fresh salt and stores the algorithm, its cost and
the salt in the string, so the database needs one text column and
verifyPassword needs nothing else. Argon2id uses 64 MiB per hash on purpose:
that is what makes guessing expensive. verifyPassword also reads bcrypt and
scrypt hashes from other systems, which lets you upgrade on the next login.
The bundled password module is about policy, not storage: validate explains
what a password lacks (hunter2 is too short, without an uppercase letter
or a symbol), generate mints a random one. The hash is shortened here.
-->

---

## TOTP: enrolment is a URI and a QR code

```jennifer excerpt
def secret as string init totp.generateSecret();
def link as string init
    totp.uri("Shelf", "ada@example.org", $secret, $o);
def qr as barcode.Symbol init barcode.encode("qr", $link, $bo);
fs.writeBytes("enrol.png", barcode.png($qr, $bo));
```

![The enrolment QR code](totp-enrol.png)

<!-- notes:
generateSecret draws 20 random bytes, the length RFC 6238 recommends, as
base32. uri builds the otpauth link authenticator apps understand, and the
bundled barcode module turns it into a PNG without any image library; the
image is the real output, and a phone app scans it. The secret here is a
throwaway from the demo run. The program also prints the link: the otpauth scheme, the label
Shelf:ada@example.org, the secret, issuer, algorithm SHA1, 6 digits and a
30 second period. Store the secret encrypted, and mark the
account as enrolled only after the user has typed one valid code.
-->

---

## TOTP: a window, and no second use

```jennifer excerpt
func stepOf(code as string, now as int, o as totp.Options) {
    def found as int init -1;
    for (def d in -1..2) { # -1, 0, 1: half-open, one step each side
        def at as int init $now + $d * 30;
        def want as string init totp.generateAt(SECRET, $at, $o);
        if (hash.equal(utf8($want), utf8($code))) { $found = $at // 30; }
    }
    return $found;
}
```

```text
verify true, old code false
985187 ok, step 59836375
985187 refused
```

<!-- notes:
totp.verify accepts the current 30-second step and one on each side, with a
constant-time compare, and stepOf checks the same three: the range -1..2 is
half-open, so it stops before 2. It does not remember anything, so a code seen over a
shoulder works again for up to ninety seconds. stepOf tells which step
matched (utf8 is convert.bytesFromString); login stores the last accepted step per user and refuses any step
not newer than it. The old code is from ninety seconds ago. Rate-limit the
form too: six digits are a million guesses. In 0.26.0 a negative digits or
period silently falls back to the default; the next release refuses it.
-->

---

## JWT: sign, then verify against a policy

```jennifer excerpt
def claims as json.Value init json.decode('{"sub":"ada",' +
    '"iss":"https://shelf.example.org","aud":"shelf-api"}');
$claims = json.set($claims, "/exp", $now + 900);
def token as string init jwt.sign("EdDSA", $claims, $kp.private);
def policy as jwt.Policy init jwt.Policy{
    iss: "https://shelf.example.org",
    aud: "shelf-api", requireExp: true, leeway: 30};
def back as json.Value init
    jwt.verifyWith("EdDSA", $token, $kp.public, $policy);
```

```text
eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhZGEiLCJpc3M...
sub=ada
```

<!-- notes:
A JWT is base64url of a header, the claims and a signature; anyone can read
the claims, so never put a secret in them. Sign with EdDSA when the verifier
is another service: it gets the public key and cannot mint tokens. HS256
needs a secret of at least 32 bytes. verify checks exp and nbf when present,
but RFC 7519 makes exp optional; the Policy makes it mandatory and pins the
issuer and audience, with 30 seconds of clock leeway. Keep tokens short-lived:
fifteen minutes here.
-->

---

## JWT: what `verifyWith` refuses

```jennifer excerpt
attempt("none", b64('{"alg":"none"}') + "." + $body + ".",
    $kp.public, $p);
attempt("confused", jwt.sign("HS256", $c, $kp.public), $kp.public, $p);
attempt("tampered", $parts[0] + "." + $evil + "." + $parts[2],
    $kp.public, $p);
attempt("expired", jwt.sign("EdDSA", $c, $kp.private), $kp.public, $p);
```

```text
none: jwt.verify: token algorithm does not match the expected EdDSA
confused: jwt.verify: token algorithm does not match the expected EdDSA
tampered: jwt.verify: signature verification failed
expired: jwt.verify: token has expired
```

<!-- notes:
The caller names the algorithm it expects, and the header must agree. That
closes the two classic attacks: alg none, an unsigned token some libraries
accepted, and algorithm confusion, an HS256 token whose HMAC key is the
verifier's public key. none is not even a known algorithm: jwt.verify("none",
...) throws unsupported algorithm. The tampered token swaps the claims and
keeps the signature. Every refusal is kind value; answer 401 and log the
message, never the token. attempt catches the error and prints the
message. A token for another audience fails the same way, in verifyWith.
-->

---

## OAuth2: a service as itself

```jennifer excerpt
def cfg as oauth.Config;
$cfg.tokenUrl = "http://127.0.0.1:9400/token";
$cfg.clientId = "shelf-worker";
$cfg.clientSecret = os.getEnv("SHELF_CLIENT_SECRET");
def tok as oauth.Token init oauth.clientCredentials($cfg);
$cfg.clientSecret = "wrong";
try { oauth.clientCredentials($cfg); } catch (e) {
    if ($e.kind != "oauth") { throw $e; }
    io.printf("%s %d | %s\n", $e.errorCode, $e.status, $e.message);
}
```

```text
Bearer at-jwX..., expires 1795094904, expired false
invalid_client 400 | invalid_client: bad client secret
```

<!-- notes:
Client credentials is OAuth2 for a program with no user: a worker trades its
own id and secret for an access token. The token URL must be https; plain
http is accepted only on this machine, which is what the demo uses. Every
failure the provider reports is an oauth.OAuthError with the provider's
errorCode and HTTP status, so match the kind first and then read the fields.
net, timeout, limit and closed pass through unchanged. isExpired keeps a 30
second margin; ask for a new token when it says true.
-->

---

## OAuth2: authorization code with PKCE

```jennifer excerpt
def srv as httpd.Server init httpd.listen("127.0.0.1:0");
def req as oauth.AuthRequest init oauth.authorize($cfg,
    "http://" + httpd.address($srv) + "/callback");
def waiter as task of string init
    spawn { return oauth.awaitCode($req, $srv); };
# ... the user signs in; the browser lands on /callback
def code as string init task.wait($waiter);
httpd.shutdown($srv);
def tok as oauth.Token init oauth.exchangeCode($cfg, $req, $code);
```

```text
browser: 200 Signed in. You can close this window.
access at-Dg-..., refresh rt-AKV...
```

<!-- notes:
The sign-in flow for a program on the user's machine. authorize makes a
random state and a PKCE verifier, and puts only the verifier's SHA-256, the
code challenge, into the URL. awaitCode serves the loopback redirect, checks
the state in constant time and ignores strangers. exchangeCode sends the
verifier, so a stolen code is useless without it; the fake server checks
exactly that. In the demo the browser is two http.get calls following the
302. To bound the wait, use task.waitTimeout and shut the server down.
-->

---

## OAuth2: refresh, rotation, and the token file

```jennifer excerpt
def old as string init $tok.refreshToken;
$tok = oauth.refresh($cfg, $tok.refreshToken);
try {
    oauth.refresh($cfg, $old);
} catch (e) {
    if ($e.kind != "oauth") { throw $e; }
    io.printf("reuse: %s (%s)\n", $e.errorCode, $e.description);
}
oauth.save("token.json", $tok);
```

```text
refreshed: refresh rt-2Ql...
reuse: invalid_grant (refresh token revoked or reused)
$ stat -c '%a %n' token.json
600 token.json
```

<!-- notes:
Servers that rotate refresh tokens hand out a new one with every refresh and
refuse the old one. refresh keeps the old token only when the reply has
none. invalid_grant is the answer to act on: the login is gone, so send the
user through sign-in again rather than retrying. save writes owner-only,
syncs, and renames over the old file, so a crash never leaves half a token.
In 0.26.0 oauth.load wraps a read failure into kind oauth, a cap included;
the next release lets limit through.
-->

---

## ACME: account, order, challenge

```jennifer excerpt
def c as acme.Client init acme.connect(CA, accountKey("account.pem"));
$c = acme.register($c, "ops@example.org");
def o as acme.Order init acme.order($c, [DOMAIN]);
def az as acme.Authorization init
    acme.authorization($c, $o.authorizations[0]);
def ch as acme.Challenge init acme.challenge("http-01", $az);
def srv as httpd.Server init httpd.listen("127.0.0.1:5002");
def answer as string init acme.keyAuthorization($c, $ch.token);
def web as task of null init
    spawn { serveChallenge($srv, $ch.token, $answer); };
```

```text
account https://127.0.0.1:14000/my-account/57766b11a0899f75
order pending, 1 authorization(s)
```

<!-- notes:
ACME is how Let's Encrypt issues certificates. The account key signs every
request, so accountKey loads it from an owner-only file and creates it once.
An order lists the domains; each gets an authorization with challenges. For
http-01 the CA fetches /.well-known/acme-challenge/ plus the token from the
domain on port 80, here pebble's port 5002, and expects the key
authorization. serveChallenge is an httpd accept loop answering that one
path. CA is pebble's directory URL on port 14000 of 127.0.0.1, and pebble's own
root is given to Jennifer with SSL_CERT_FILE. The prints are left out.
-->

---

## ACME: prove it, check it, finalize

```jennifer excerpt
acme.accept($c, $ch.url);
def done as acme.Authorization init
    acme.pollAuthorization($c, $o.authorizations[0], 1000, 30);
stopServer($srv, $web);
if ($done.status != "valid") { notValidated($done); }
def certKey as crypto.Keypair init crypto.keypair("p256");
def csr as bytes init crypto.csr($certKey.private, [DOMAIN]);
$o = acme.finalize($c, $o, $csr, 1000, 30);
def pem as string init acme.downloadCertificate($c, $o);
```

```text
order valid, 2063 bytes of PEM
# the same program, serving a wrong answer:
shelf.example.test: authorization invalid
```

<!-- notes:
accept tells the CA to look, and pollAuthorization waits for a result. In
0.26.0 it returns as soon as the status leaves pending, an invalid one
included, so the status check is yours to write; the last line is the
same program answering a wrong body; notValidated prints and exits 1. A
CA may also reuse an earlier valid authorization: the order then arrives
ready, and accepting its challenge again is refused, so check the status
before you accept. The certificate key is a second key,
never the account key, and goes into an owner-only key.pem. finalize sends
the CSR and polls until the order is valid. Also in 0.26.0: connect accepts
a plain http directory, so pin https yourself.
-->

---

## When to renew

```jennifer excerpt
def cert as asn1.Value init
    asn1.decode(encoding.fromText("base64", $b64));
def s as string init convert.stringFromBytes("utf-8",
    asn1.asBytes($cert, "/0/4/{$which}"));   # notBefore, notAfter
# ...
def life as int init time.unix($ends) - time.unix($from);
def left as int init time.unix($ends) - time.unix(time.now());
if ($left < $life // 3) {
    io.printf("renew now\n");
}
```

```text
expires 2027-02-17, 89 of 89 days left
```

<!-- notes:
Renew from the certificate itself, not from a date you wrote down. The asn1
library reads the validity dates straight out of the DER: field 4 of the
to-be-signed part, UTCTime text such as 270217122208Z. Renew when a third of
the lifetime is left, thirty days of a ninety-day certificate, which is
what Let's Encrypt suggests, and check daily so a failed renewal has weeks
of retries. Lifetimes are getting shorter, so never hard-code ninety days.
pebble issues ninety-day certificates, like Let's Encrypt today.
-->

---

## Sealed secrets with `@deckyard/sealbox`

```jennifer excerpt
import "@deckyard/sealbox/" as sealbox;

def key as bytes init sealbox.newKey();
def id as bytes init convert.bytesFromString("utf-8", "row 17");
def box as bytes init sealbox.sealWith($plain, $key, $id);
def other as bytes init convert.bytesFromString("utf-8", "row 18");
sealbox.openWith($box, $key, $other);
def tok as string init sealbox.fernetEncrypt($plain, $fkey);
```

```text
box 52 bytes for 24
sealbox | sealbox: cannot open (wrong key, or the data was changed)
fernet gAAAAABq_uraUoQ5EljskIId...
```

<!-- notes:
The deck packages crypto.encrypt into formats, so you never handle a nonce:
seal stores a fresh one in front of an AES-256-GCM box. sealWith binds
associated data, here the row id, so a box copied into another row does not
open. Every failure to open is the same sealbox error, by design. Fernet
tokens interoperate with Python's cryptography package. Install with jvc
add @deckyard/sealbox, which vendors it from the registry; the deck needs no
capabilities and also runs on jennifer-tiny.
-->

---

## Keys: owner-only files, ids, rotation

```jennifer excerpt
func keyFile(path as string) {
    if (fs.stat($path).mode & 0o077 != 0) {
        throw Error{kind: "config",
            message: $path + " is readable by others"};
    }
    return fs.readString($path);
}
def old as string init jwt.signWithKid("HS256", $c,
    convert.bytesFromString("utf-8", $keys["2026-10"]), "2026-10");
def back as json.Value init jwt.verifyWithKeys("HS256", $t, $keys);
```

```text
config | run/jwt-2026-11 is readable by others
kid 2026-10: sub=ada
kid 2026-11: sub=ada
```

<!-- notes:
Keys never go into the source or the repository. Read them from a file the
environment names, as the web app talk does with its _FILE variables, and
refuse a file others can read. Give every key an id: tokens carry it as
kid, and verifyWithKeys picks the key from a map. To rotate, add the new key,
sign with it, keep the old one until its last token has expired, then drop
it. A leaked key is rotated the same way, only now. The files hold
placeholder keys.
-->

---

## Errors and their kinds

| Where | Kind | Carries |
| --- | --- | --- |
| `crypto.decrypt` | `"runtime"` | one vague message |
| `totp`, `jwt` | `"totp"`, `"value"` | a message |
| `oauth` | `"oauth"`: `OAuthError` | `errorCode`, `status` |
| `acme` | `"acme"`: `AcmeError` | `problemType`, `retryAfter` |
| `@deckyard/sealbox` | `"sealbox"` | one vague message |
| `http` underneath | `net`, `timeout`, `limit`, `closed` | passed on |

<!-- notes:
Dispatch on kind, then read the fields of the module's struct; never parse
a message. A rate-limited ACME client reads retryAfter, an OAuth client
treats invalid_grant as a lost login, and both let the generic kinds through
to the retry logic. Crypto failures are deliberately vague: telling a wrong
key from a changed byte helps an attacker. Log the kind and message, answer
the client with a bare 401 or 403, and never log a token, a key or a
password.
-->

---

## Checklist

- Pick the tool by the question: hash, MAC, cipher, signature
- Compare secrets with `hash.equal`; store passwords with `argon2id`
- TOTP: window of one step, remember the last step, rate-limit
- JWT: pin the algorithm, `requireExp`, check `iss` and `aud`, short lives
- OAuth2: PKCE and state for users, `invalid_grant` means sign in again
- ACME: check the authorization status, separate keys, renew at a third
- Keys: owner-only files, an id on every key, rotate on a schedule

<!-- notes:
The whole talk on one slide. Most of the list is not about algorithms, which
the libraries choose well, but about the checks around them that only the
caller can make: which algorithm to expect, which audience a token is for,
whether a code was used before, whether a challenge really succeeded, and
where a key lives. Those are the places where real systems break.
-->

---

## Read more

- Libraries: [crypto](https://github.com/jennifer-language/jennifer/blob/main/docs/libraries/crypto.md)
  and [hash](https://github.com/jennifer-language/jennifer/blob/main/docs/libraries/hash.md)
- Modules: `docs/modules/` `totp.md`, `jwt.md`, `oauth.md`, `acme.md`, `barcode.md`
- Deck: [deck-sealbox](https://registry.jennifer-lang.dev/deck/deckyard/sealbox) in the
  [registry](https://registry.jennifer-lang.dev/)
- Companions: [Jennifer facing hostile input](https://academy.jennifer-lang.dev/talks/mplx/security/)
  and [A web app from scratch](https://academy.jennifer-lang.dev/talks/mplx/web-app/)

Based on Jennifer 0.26.0, November 2026.

<!-- notes:
The crypto page lists every algorithm with its key sizes and limits, and
explains nonces, key agreement and ML-KEM, which this talk left out. Each
module page has the full API and its error struct. The security talk covers
caps, parsing and the trust model; the web app talk shows argon2id logins,
sessions and CSRF in a complete application.
-->
