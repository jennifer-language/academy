# Network tools: the code

The programs behind the slides, for Jennifer 0.26.0. `ipnet`, `idna`,
`snmp`, `ntp` and `ldap` are bundled modules, so no `jvc install` is needed.
Run everything from this folder. The ipnet, idna and LDAP test programs need
nothing else; the others talk to throwaway containers bound to localhost
(stop them with `docker rm -f nt-snmpd nt-chrony nt-ldap`).

## Servers

```sh
docker run --rm -d --name nt-snmpd -p 127.0.0.1:16161:161/udp -v "$PWD/snmp/snmpd.conf:/etc/snmp/snmpd.conf:ro" alpine:3.20 sh -c "apk add --no-cache net-snmp && exec snmpd -f -Lo -c /etc/snmp/snmpd.conf udp:161"
docker run --rm -d --name nt-chrony -p 127.0.0.1:10123:123/udp -v "$PWD/chrony/chrony.conf:/etc/chrony/chrony.conf:ro" alpine:3.20 sh -c "apk add --no-cache chrony && exec chronyd -d -x -f /etc/chrony/chrony.conf"
sh ldap/make-certs.sh
docker run --rm -d --name nt-ldap -p 127.0.0.1:10389:389 -p 127.0.0.1:10636:636 -v "$PWD/ldap/certs:/container/service/slapd/assets/certs" -v "$PWD/ldap/ldif:/container/service/slapd/assets/config/bootstrap/ldif/custom" -e LDAP_DOMAIN=example.org -e LDAP_ADMIN_PASSWORD=admin-pw-2026 -e LDAP_READONLY_USER=true -e LDAP_READONLY_USER_USERNAME=reader -e LDAP_READONLY_USER_PASSWORD=reader-pw-2026 -e LDAP_TLS_CRT_FILENAME=ldap.crt -e LDAP_TLS_KEY_FILENAME=ldap.key -e LDAP_TLS_CA_CRT_FILENAME=ca.crt -e LDAP_TLS_DH_PARAM_FILENAME=dhparam.pem -e LDAP_TLS_VERIFY_CLIENT=never -e LDAP_TLS_ENFORCE=true osixia/openldap:1.5.0 --copy-service
docker exec -i nt-ldap ldapmodify -Y EXTERNAL -H ldapi:/// < ldap/limits.ldif
```

- `snmp/snmpd.conf`: net-snmp with the read-only community `public`.
- `chrony/chrony.conf`: chrony serving its local clock; `-x` keeps it from
  setting the clock.
- `ldap/make-certs.sh`: makes a throwaway lab CA and a server certificate for
  `localhost` in `ldap/certs/`, and copies the CA to `lab-ca.pem` here. No key
  or certificate is shipped.
- `ldap/ldif/50-lab.ldif`: alice, bob, carol and 40 test users, and the groups
  `netops` and `helpdesk`. The passwords are placeholders.
- `ldap/limits.ldif`: one way to lower the server's limits for the reader
  account to 20 entries per search and 25 per page, as in the lab, so the
  plain search in `ldap_paged.j` fails with code 4.

The LDAP programs read the reader's password from `LDAP_PW`, and `ldap.connect`
checks StartTLS against the system roots, so set both:
`export LDAP_PW=reader-pw-2026 SSL_CERT_FILE=lab-ca.pem`.

## Programs

- `ipnet_first.j`: one bundled import, no vendor/ ("Five modules, one
  toolbox"). Run: `jennifer run ipnet_first.j`
- `ipnet_addresses.j`: parse, contains, IPv6 normal form, IPv4-mapped
  addresses ("ipnet: addresses and networks").
  Run: `jennifer run ipnet_addresses.j`
- `ipnet_subnets.j`: netmask, host count, last usable, split ("ipnet: subnet
  arithmetic"). Run: `jennifer run ipnet_subnets.j`
- `ipnet_scope.j`: the scope of seven addresses ("ipnet: what kind of
  address is it?"). Run: `jennifer run ipnet_scope.j`
- `idna_convert.j`: `toAscii`, `toUnicode`, a label that is too long ("idna:
  international domain names"). Run: `jennifer run idna_convert.j`
- `idna_spoof.j`: a Cyrillic look-alike of apple.example, flagged by script
  ("idna: why spoofing matters"). Run: `jennifer run idna_spoof.j`
- `snmp_get_walk.j`: get and walk against `nt-snmpd` ("SNMP: get and walk").
  Run: `jennifer run snmp_get_walk.j`
- `snmp_bandwidth.j`: two samples five seconds apart and a 32-bit wrap
  ("SNMP: bandwidth from two samples"). Needs `nt-snmpd`.
  Run: `jennifer run snmp_bandwidth.j`
- `snmp_agent.j`: a tiny agent on UDP `127.0.0.1:16170` that serves the
  number of files in `spool/` and refreshes every ten seconds ("SNMP: a tiny
  agent for your own values"). Run: `jennifer run snmp_agent.j` (stays
  running), then `jennifer run snmp_agent_query.j`; add a file to `spool/`
  and query again after ten seconds.
- `ntp_query.j`: one SNTP query to `pool.ntp.org`; needs Internet access
  ("NTP: ask a server for the time"). Run: `jennifer run ntp_query.j`
- `ldap_tls.j`: the same bind over StartTLS, LDAPS (with `lab-ca.pem`) and
  plain TCP, which the server refuses with code 13 ("LDAP: never bind in plain
  text"). Needs `nt-ldap`. Run: `jennifer run ldap_tls.j`
- `dirauth.j`: the helpers `userDn`, `passwordOk` and `groupsOf`, imported by
  the next three programs ("LDAP: users and groups", "LDAP: check a password
  with bind").
- `ldap_search.j`: an escaped filter value and alice's groups ("LDAP: users
  and groups"). Needs `nt-ldap`. Run: `jennifer run ldap_search.j`
- `ldap_password.j`: a password check by bind, and a user who does not exist
  ("LDAP: check a password with bind"). Needs `nt-ldap`.
  Run: `jennifer run ldap_password.j`
- `ldap_paged.j`: `searchPaged` and the size limit of a plain search ("LDAP:
  large result sets"). Needs `nt-ldap` with `ldap/limits.ldif` applied.
  Run: `jennifer run ldap_paged.j`
- `dirauth_test.j`: tests `dirauth.j` against the module's in-memory
  directory server; needs no container ("LDAP: a directory server for your
  tests"). Run: `jennifer test dirauth_test.j`
- `errors.j`: a closed NTP port, a wrong SNMP community, a closed SNMP port,
  a refused SET, a closed LDAP port and TLS on the plain LDAP port ("Errors,
  timeouts and limits"). Needs `nt-snmpd` and `nt-ldap`.
  Run: `jennifer run errors.j`
- `report.j`: the network health report: NTP drift, SNMP rates, a switch that
  is down (nothing on port 16171), an address outside the management networks
  and an LDAP count; exits 1 on any FAIL or WARN ("NTP: a drift check that
  warns", "Project: a network health report", "The report"). Needs all three
  containers. Run:
  `SNMP_COMMUNITY=public LDAP_BIND_DN=cn=reader,dc=example,dc=org LDAP_PW=reader-pw-2026 SSL_CERT_FILE=lab-ca.pem jennifer run report.j`
