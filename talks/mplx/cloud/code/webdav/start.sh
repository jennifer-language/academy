#!/bin/sh
# Start Apache httpd 2.4 with mod_dav on 127.0.0.1:18081, user alice.
# Run from code/webdav/. The password is a placeholder; httpd.conf is the
# image's default plus the /dav section at its end.
set -e
cd "$(dirname "$0")"
docker run --rm httpd:2.4 htpasswd -nbB alice example-password > htpasswd
docker rm -f academy-cloud-webdav >/dev/null 2>&1 || true
docker run -d --name academy-cloud-webdav -p 127.0.0.1:18081:80 \
    -v "$PWD/httpd.conf:/usr/local/apache2/conf/httpd.conf:ro" \
    -v "$PWD/htpasswd:/usr/local/apache2/conf/htpasswd:ro" httpd:2.4 \
    sh -c 'mkdir -p /usr/local/apache2/davroot /usr/local/apache2/var &&
        chown www-data /usr/local/apache2/davroot /usr/local/apache2/var &&
        exec httpd-foreground'
