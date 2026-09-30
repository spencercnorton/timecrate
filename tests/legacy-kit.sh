#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2026 Spencer Norton
#
# Write one kit exactly as releases before 3.0.0 did, so the suite can prove that this release
# still lists, verifies, restores and prunes the kits already on a remote. These are the lines of
# release 2.14.0's `backup` that decide what a kit is: its name, the manifests directory inside
# it, the tar | zstd | gpg pipeline with its flags, and the two sidecars. Only the choice of files
# and the manifest contents are reduced.
#
#   legacy-kit.sh <out-dir> <timestamp> <gnupg-home> <recipient-fpr> <signing-fpr> <path>...
#
# <timestamp> is YYYY-MM-DD_HH-MM-SS; each <path> is relative to /, as an include list names it.
set -euo pipefail
[ $# -ge 6 ] || { echo "usage: $0 <out-dir> <timestamp> <gnupg-home> <recipient> <signer> <path>..." >&2; exit 2; }
out="$1" ts="$2" gnupghome="$3" recipient="$4" signer="$5"; shift 5

PREFIX="timemachine" VERSION="2.14.0" CIPHER="AES256" ZSTD_LEVEL=19 ZSTD_LONG=27
stage="$(mktemp -d)"; trap 'rm -rf -- "$stage"' EXIT
man="$stage/TIMEMACHINE-MANIFESTS"; mkdir -p "$man"
dpkg --get-selections > "$man/dpkg-selections.txt" 2>/dev/null || : > "$man/dpkg-selections.txt"
cp /etc/os-release "$man/os-release.txt" 2>/dev/null || true
printf 'time-machine %s @ %s on %s\n' "$VERSION" "$(date -Is)" "$(hostname)" > "$man/BACKUP-INFO.txt"

kit="$out/${PREFIX}-${ts}.tar.zst.gpg"
tar --numeric-owner --acls --xattrs --sparse -p --ignore-failed-read \
    --warning=no-file-changed --warning=no-file-removed -cf - \
    -C / "$@" \
    -C "$stage" TIMEMACHINE-MANIFESTS \
  | zstd -q -T0 --long=$ZSTD_LONG "-$ZSTD_LEVEL" \
  | GNUPGHOME="$gnupghome" gpg --batch --yes --trust-model always \
      --cipher-algo "$CIPHER" --compress-algo none \
      --sign -u "$signer" -e -r "$recipient" -o "$kit.part"
mv "$kit.part" "$kit"
( cd "$out" && sha256sum "$(basename "$kit")" ) > "$kit.sha256"
printf '{"prefix":"%s","ts":"%s","host":"%s","tm_version":"%s","cipher":"%s","zstd_level":%s,"zstd_long":%s,"bytes":%s,"sha256":"%s"}\n' \
  "$PREFIX" "$ts" "$(hostname)" "$VERSION" "$CIPHER" "$ZSTD_LEVEL" "$ZSTD_LONG" \
  "$(stat -c %s "$kit")" "$(cut -d' ' -f1 "$kit.sha256")" > "$out/${PREFIX}-${ts}.meta.json"
printf '%s\n' "$kit"
