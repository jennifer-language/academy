#!/bin/sh
set -eu
v="$1"
stage="jennifer-$v-linux-amd64"
base="https://github.com/jennifer-language/jennifer"
base="$base/releases/download/$v"
mkdir -p .ci && cd .ci
curl -fsSLO "$base/$stage.tar.gz"
curl -fsSLO "$base/$stage.tar.gz.sha256"
sha256sum -c "$stage.tar.gz.sha256"
tar xzf "$stage.tar.gz"
echo "$PWD/$stage" >> "$GITHUB_PATH"
echo "JENNIFER_SYSMODDIR=$PWD/$stage/share/jennifer/modules" \
    >> "$GITHUB_ENV"
