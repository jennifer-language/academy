#!/bin/sh
# setup-jellyfin.sh - finish the first-run wizard of a fresh Jellyfin on
# 127.0.0.1:18096 and add two libraries (movies, music) with every internet
# metadata and image fetcher switched off, so the server only reads the NFO
# files and tags beside the media. Placeholder credentials only.
set -eu
URL=${JELLYFIN_URL:-http://127.0.0.1:18096}
USER=${JELLYFIN_USER:-jen}
PASS=${JELLYFIN_PASSWORD:-change-me-please}
H='Content-Type: application/json'
AUTH='MediaBrowser Client="setup", Device="sh", DeviceId="setup-sh-0001", Version="1.0"'

curl -sf -X POST -H "$H" "$URL/Startup/Configuration" \
  -d '{"UICulture":"en-US","MetadataCountryCode":"US","PreferredMetadataLanguage":"en"}'
curl -sf "$URL/Startup/User" >/dev/null
curl -sf -X POST -H "$H" "$URL/Startup/User" -d "{\"Name\":\"$USER\",\"Password\":\"$PASS\"}"
curl -sf -X POST -H "$H" "$URL/Startup/RemoteAccess" \
  -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}'
curl -sf -X POST "$URL/Startup/Complete"

TOKEN=$(curl -sf -X POST -H "$H" -H "Authorization: $AUTH" \
  "$URL/Users/AuthenticateByName" -d "{\"Username\":\"$USER\",\"Pw\":\"$PASS\"}" |
  sed 's/.*"AccessToken":"\([^"]*\)".*/\1/')
A="Authorization: $AUTH, Token=\"$TOKEN\""

offline() { # the LibraryOptions of a library that never asks the internet
  printf '{"LibraryOptions":{"EnableRealtimeMonitor":false,"EnableInternetProviders":false,'
  printf '"DisabledLocalMetadataReaders":[],"MetadataSavers":[],'
  printf '"TypeOptions":[{"Type":"%s","MetadataFetchers":[],"ImageFetchers":[]}],' "$1"
  printf '"PathInfos":[{"Path":"%s"}]}}' "$2"
}
curl -sf -X POST -H "$H" -H "$A" \
  "$URL/Library/VirtualFolders?name=Movies&collectionType=movies&refreshLibrary=false" \
  -d "$(offline Movie /media/movies)"
curl -sf -X POST -H "$H" -H "$A" \
  "$URL/Library/VirtualFolders?name=Music&collectionType=music&refreshLibrary=false" \
  -d "$(offline MusicAlbum /media/music)"
echo "Jellyfin at $URL: user $USER, libraries Movies and Music (not scanned yet)"
