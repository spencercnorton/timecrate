#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2026 Spencer Norton
#
# Deliver one alert, the same way for every caller.
#   alert.sh <severity> <title> [key]     the message on stdin
#   alert.sh --unit-failed <unit>         the OnFailure= path: a unit died (timeout, OOM, kill)
#
# Every alert goes to standard error, which systemd writes to the journal. When
# TIMECRATE_ALERT_CMD names an executable it is also run, as
#   <command> <severity> <title> <key>    with the message on stdin,
# and this script exits with its status. Severity is critical, warn or info. The key names the
# kind of alert (backup, remote, drill, capstone, overnight, unit-<name>, test), so a receiver can
# update one message in place instead of adding another.
#
# Self-contained on purpose: the OnFailure= path has to work when the engine is what broke.
set -u
cmd="${TIMECRATE_ALERT_CMD:-}"   # the environment wins over the files, as it does for the engine
for f in "${TIMECRATE_SYSTEM_CONF:-/etc/timecrate/timecrate.conf}" "${TIMECRATE_SECRET_ENV:-/etc/timecrate.env}"; do
  # shellcheck disable=SC1090
  [ -r "$f" ] && { set -a; . "$f"; set +a; }
done
cmd="${cmd:-${TIMECRATE_ALERT_CMD:-}}"

if [ "${1:-}" = --unit-failed ]; then
  unit="${2:-unknown}"
  set -- critical "Timecrate unit $unit failed on $(hostname)" "unit-$unit"
  # "may not have been sent": OnFailure= fires on any failed result, including a run whose own
  # alert already went out. A duplicate is acceptable; a misleading message is not.
  body="The unit ended in failure (a timeout, a crash or a kill), so the alert from inside the run may not have been sent. Investigate: journalctl -u $unit"
else
  body="$(cat)"
fi
sev="${1:-critical}" title="${2:-Timecrate alert}" key="${3:-}"

printf '[timecrate][ALERT] %s: %s\n%s\n' "$sev" "$title" "$body" >&2
[ -n "$cmd" ] || exit 0
if [ ! -x "$cmd" ]; then
  printf '[timecrate][ALERT] TIMECRATE_ALERT_CMD=%s is not an executable file, so this alert was NOT delivered\n' "$cmd" >&2
  exit 1
fi
printf '%s\n' "$body" | "$cmd" "$sev" "$title" "$key"
rc=$?
[ "$rc" = 0 ] || printf '[timecrate][ALERT] %s exited %s, so this alert was NOT delivered\n' "$cmd" "$rc" >&2
exit "$rc"
