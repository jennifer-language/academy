#!/bin/sh
# Generates a throwaway lab CA and a server certificate for localhost and
# 127.0.0.1 into ldap/certs/, and copies the CA to lab-ca.pem next to the
# programs. Run from code/: sh ldap/make-certs.sh
set -eu
d=ldap/certs
mkdir -p "$d"
openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=Example Lab CA" \
    -keyout "$d/ca.key" -out "$d/ca.crt"
openssl req -newkey rsa:2048 -nodes -subj "/CN=localhost" \
    -keyout "$d/ldap.key" -out "$d/ldap.csr"
printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\n' > "$d/ext.cnf"
openssl x509 -req -in "$d/ldap.csr" -CA "$d/ca.crt" -CAkey "$d/ca.key" \
    -CAcreateserial -days 30 -extfile "$d/ext.cnf" -out "$d/ldap.crt"
openssl dhparam -out "$d/dhparam.pem" 2048
cp "$d/ca.crt" lab-ca.pem
echo "certificates in $d, CA copied to lab-ca.pem"
