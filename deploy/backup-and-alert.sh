#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2026 Spencer Norton
#
# The scheduled backup: run it, and alert on a failure or on a remote that lost kits.
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
TC="$(command -v timecrate 2>/dev/null || echo "$HERE/../timecrate")"
[ -x "$TC" ] || { echo "timecrate not found on PATH" >&2; exit 1; }
HOST="$(hostname)"

OUT="$("$TC" backup 2>&1)"; RC=$?
printf '%s\n' "$OUT"

# REMOTE-ALERT = the daily pre-upload anchor check found deletion or rollback on a remote. The
# backup itself still succeeds (never stop backing up because kits were deleted), but this must
# alert NOW: a provider keeps deleted files for a limited time, and a monthly drill is too late.
if printf '%s' "$OUT" | grep -q 'REMOTE-ALERT'; then
  printf 'Timecrate found kits deleted or rolled back on a remote of %s. The backup itself is OK.\n\n%s\n\n%s\n' \
    "$HOST" "$(printf '%s' "$OUT" | grep 'REMOTE-ALERT' | tail -3)" \
    "Recover them from the provider's version history before it expires." \
    | "$HERE/alert.sh" critical "Timecrate REMOTE deletion or rollback on $HOST" remote
fi

[ "$RC" -eq 0 ] && exit 0
printf 'Timecrate BACKUP FAILED on %s (rc=%s). The off-site copy did not update.\n\n%s\n' \
  "$HOST" "$RC" "$(printf '%s' "$OUT" | tail -5)" \
  | "$HERE/alert.sh" critical "Timecrate backup FAILED on $HOST" backup
exit "$RC"
