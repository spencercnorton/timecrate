# Changelog

All notable changes to Timecrate are documented here.

## 3.0.0 — 2026-09-30

The first public release, and a new name: releases before it were packaged as `time-machine` and
`time-machine-gui`. [docs/MIGRATING.md](docs/MIGRATING.md) moves a machine across.

- **Kits written before 3.0.0 are the same series.** `timemachine-*` kits already on a remote are
  listed, verified, restored, drilled and pruned together with new `timecrate-*` kits, ordered by
  timestamp; retention counts each kit once, and an anti-rollback anchor written by an earlier
  version is read correctly.
- **The timers are armed on install and stay armed across upgrades.** The backup, drill and
  capstone timers are enabled when the package is installed; an upgrade no longer stops them, and
  a timer you disabled stays disabled. The capstone is skipped on a machine without multipass.
- **Alerts go to a command you choose.** `TIMECRATE_ALERT_CMD` is run with the severity, a title
  and a key, and the message on standard input. Without it, alerts are written to the journal.
- **The off-box escrow copy is reached through a command you choose.** `TIMECRATE_ESCROW_KEY_CMD`
  gives the monthly drill the escrowed key to prove, and lets `harden` check it by fingerprint.
- **Include lines may be globs.** Nothing is added to a kit that the include list does not name.
- **Upload is refused while the previous package's backup timer is armed**, so the two versions
  cannot prune one remote at once.
- rclone's own notices are no longer read as kits: listings are parsed from rclone's output alone,
  so a `NOTICE:` line no longer shows up in `list`, counts in `verify --all` or fails the drill.
- `init` works as the user on a fresh install; it no longer needs the root-owned staging directory.
- Include entries under `~/` are no longer reported missing when they exist.
- The capstone's reboot check is generic: every restored file must survive the reboot, and each
  sysctl key named in `TIMECRATE_CAPSTONE_SYSCTL` must be in effect with its restored value.
- The capstone reads the per-user configuration, as the engine does.
- The About window names the licence correctly, GPL-2.0-or-later.
- A new icon, a crate.
