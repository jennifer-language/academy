# Email with Jennifer: the code

The programs behind the slides, for Jennifer 0.27.0 and its bundled modules
(`smtp.j`, `imap.j`, `pop.j`, `mime.j`, `sasl.j`, `oauth.j`,
`transport.j`). No decks. They talk to local stand-in servers in docker, not
to a real mail provider: GreenMail 2.1.2 (SMTP, IMAP, POP3 over implicit
TLS), Dovecot 2.3.21 (STARTTLS and XOAUTH2) with a small mock OAuth2
provider, and Mailpit 1.21 (STARTTLS submission). Every address is
`example.org` or `example.com`, and `changeme` / `changeit` / `rt-demo` are
placeholders.

## Setup

From this folder:

```sh
sh setup.sh          # throwaway CA + localhost certificate, config copies, invoice-2026-11.pdf
D=/tmp/jennifer-email-demo          # or whatever MAIL_DEMO_DIR you gave setup.sh
export SSL_CERT_FILE=$D/certs/ca.pem   # trust the test CA, for every program below

docker network create academy-mail-net
docker run --rm -d --name academy-mail-greenmail -v $D/certs:/certs:ro \
  -e GREENMAIL_OPTS="-Dgreenmail.setup.test.all -Dgreenmail.hostname=0.0.0.0 -Dgreenmail.users=ada:changeme@example.org,bob:changeme@example.com -Dgreenmail.users.login=email -Dgreenmail.tls.keystore.file=/certs/server.p12 -Dgreenmail.tls.keystore.password=changeit" \
  -p 127.0.0.1:3025:3025 -p 127.0.0.1:3465:3465 -p 127.0.0.1:3143:3143 \
  -p 127.0.0.1:3993:3993 -p 127.0.0.1:3110:3110 -p 127.0.0.1:3995:3995 \
  greenmail/standalone:2.1.2
docker run --rm -d --name academy-mail-oauth --network academy-mail-net \
  -p 127.0.0.1:18080:8080 -v $D/oauthmock:/app:ro --entrypoint jennifer \
  ghcr.io/jennifer-language/jennifer:0.27.0 run /app/mock.j
docker run --rm -d --name academy-mail-dovecot --network academy-mail-net \
  -v $D/dovecot:/etc/dovecot:ro -p 127.0.0.1:4143:143 -p 127.0.0.1:4993:993 \
  -p 127.0.0.1:4110:110 -p 127.0.0.1:4995:995 dovecot/dovecot:2.3.21
docker run --rm -d --name academy-mail-mailpit -v $D/mailpit:/cfg:ro \
  -p 127.0.0.1:1587:1025 -p 127.0.0.1:18025:8025 axllent/mailpit:v1.21 \
  --smtp-tls-cert /cfg/server.pem --smtp-tls-key /cfg/server.key \
  --smtp-require-starttls --smtp-auth-file /cfg/auth.txt
```

Ports: GreenMail SMTP 3465 (TLS) and 3025 (plain), IMAP 3993 (TLS) and 3143
(plain), POP3 3995 (TLS); Dovecot IMAP 4143 and POP3 4110 (STARTTLS);
Mailpit submission 1587 (STARTTLS) and its web UI on http://127.0.0.1:18025.
GreenMail keeps mail in memory only, so restart it to start over. Stop
everything with `docker stop academy-mail-greenmail academy-mail-oauth
academy-mail-dovecot academy-mail-mailpit; docker network rm academy-mail-net`.

`servers/` holds the configs `setup.sh` copies: `dovecot/dovecot.conf` and
`dovecot/oauth2.conf` (OAuth2 token introspection against the mock),
`mailpit/auth.txt` (the one placeholder login), and `oauthmock/mock.j`, the
stand-in OAuth2 provider (a token endpoint that accepts the refresh token
`rt-demo`, and the introspection endpoint Dovecot asks).

## Programs

Run each with `jennifer run x.j` from this folder, in about this order, since
later ones read the mail earlier ones sent.

- `seed.j`: six mails to ada over one SMTP session: a newsletter, the boss,
  an invoice with a PDF, spam, a digest, a friend ("One session, many mails").
- `send.j`: multipart/alternative plus a PDF attachment, encoded-word headers,
  Date and Message-ID, sent to bob ("Composing: a tree of parts", "Headers and
  encoded words").
- `parse.j`: logs in as bob, fetches the mail with an attachment and walks
  its parts ("Parsing a received message", "TLS, STARTTLS and certificates":
  run it without `SSL_CERT_FILE` to see the untrusted CA error).
- `search.j`: select INBOX, search unseen, fetch only headers, search by
  subject, attachment and sender regex ("IMAP: select, search, fetch
  headers").
- `folders.j`: every folder with its message, unseen and next uid counts
  ("IMAP: select, search, fetch headers").
- `flags.j`: add and remove flags, MOVE, delete and expunge, append to Sent
  ("Whole messages, flags, move, delete"). Changes ada's mailbox.
- `idle.j` and `ping.j`: `idle.j` waits with IDLE for three new mails;
  `ping.j` sends them, one every two seconds ("IDLE: wait for new mail").
  Run `jennifer run idle.j &` then `jennifer run ping.j`.
- `popseed.j`, `popfetch.j`: three mails to bob, then a POP3 download that
  remembers UIDLs in `seen-uidl.txt` and deletes the "old" ones on quit
  ("POP3: download, delete, remember UIDL"). Run `popfetch.j` twice.
- `popstls.j`: POP3 with STLS against Dovecot ("TLS, STARTTLS and
  certificates").
- `safename.j`: turns hostile attachment names into safe file names, no
  server needed ("Attachments: never trust the name").
- `seed2.j`: a mail to ada with an attachment named
  `../../.config/autostart/run.pdf` ("Attachments: never trust the name").
- `filter.j`: the inbox filter: spam deleted, newsletters moved, VIP
  flagged, PDF invoices saved to `invoices/` with size caps and safe names
  ("Saving invoices with caps", "An inbox filter: the rules", "An inbox
  filter: the run"). Run it after `seed.j` and `seed2.j`; a second run stops
  at `fs.writeNew`, which refuses to overwrite.
- `errors.j`: the structured errors: `smtp.SmtpError`, `imap.ImapError`,
  `pop.PopError`, refused plaintext auth, a downgrade, command injection, a
  closed port ("Errors you will actually see").
- `inject.j`: a header value with CRLF stays one harmless line, no server
  needed ("Security and limits").
- `plain.j`: IMAP LOGIN over `Security.None`: GreenMail on 3143 lets it
  through, Dovecot on 4143 refuses ("Security and limits").
- `envelope.j`: envelope sender and recipients versus headers, a Bcc that
  is only in the envelope; against Mailpit with STARTTLS and AUTH ("Sending:
  envelope and headers"). Look at the result in Mailpit's web UI.
- `xoauth.j`: refreshes an access token at the mock provider and logs in to
  Dovecot with XOAUTH2 ("Passwords, app passwords, XOAUTH2").
  Run: `MAIL_REFRESH_TOKEN=rt-demo jennifer run xoauth.j`
- `bearer.j`: the SASL OAUTHBEARER initial response for a token, no server
  needed ("Passwords, app passwords, XOAUTH2").
