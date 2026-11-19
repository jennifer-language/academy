#!/bin/sh
# Prepares the local mail servers for the demos:
# - a throwaway test CA and a server certificate for localhost, valid 30 days,
#   in $MAIL_DEMO_DIR (default /tmp/jennifer-email-demo), outside this folder
# - copies of the Dovecot and Mailpit configs next to them, for the
#   docker -v mounts in README.md
# - invoice-2026-11.pdf, a tiny one-page PDF the programs attach, here
set -e
cd "$(dirname "$0")"
D=${MAIL_DEMO_DIR:-/tmp/jennifer-email-demo}
mkdir -p "$D/certs" "$D/dovecot" "$D/mailpit"
cp -r servers/oauthmock "$D/"

cd "$D/certs"
openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.pem \
    -days 30 -subj "/CN=Academy Demo CA" 2>/dev/null
openssl req -newkey rsa:2048 -nodes -keyout server.key -out server.csr \
    -subj "/CN=localhost" 2>/dev/null
printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\n' > ext.cnf
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
    -out server.pem -days 30 -extfile ext.cnf 2>/dev/null
# GreenMail reads a PKCS#12 keystore; changeit is a placeholder password
openssl pkcs12 -export -in server.pem -inkey server.key -certfile ca.pem \
    -out server.p12 -passout pass:changeit -name greenmail
chmod 644 ./*
cd - >/dev/null

cp servers/dovecot/dovecot.conf servers/dovecot/oauth2.conf "$D/dovecot/"
cp "$D/certs/server.pem" "$D/dovecot/cert.pem"
cp "$D/certs/server.key" "$D/dovecot/key.pem"
cp servers/mailpit/auth.txt "$D/mailpit/"
cp "$D/certs/server.pem" "$D/certs/server.key" "$D/mailpit/"

cat > invoice-2026-11.pdf <<'EOF'
%PDF-1.4
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 100]>>endobj
trailer<</Root 1 0 R>>
%%EOF
EOF
echo "ready: $D (trust it with SSL_CERT_FILE=$D/certs/ca.pem)"
