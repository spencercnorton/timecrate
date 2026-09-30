# Restoring a machine from a kit

A kit is deliberately lean: it does not contain `/usr` or the installed packages, which a package
manager can reproduce. Recovery is therefore: put the key back, reinstall the OS, replay the
package manifest, and lay the kit's configuration back on top. Work through this in order.

If Timecrate itself is not available, [BREAK-GLASS.md](BREAK-GLASS.md) does steps 2 to 4 with
nothing but `gpg`, `zstd` and `tar`.

## 0. Put the identity back first

Everything below is about getting data back. Before any of it, get the key back: the one
irreversible mistake available on a freshly reinstalled machine is generating a new key, which
would leave every kit on the remote encrypted to a key that no longer exists anywhere.

```sh
timecrate keys                                   # what, if anything, this machine holds
timecrate import-key timecrate-secret.asc \
    --signing-pub timecrate-signing-public.asc   # both are on the escrow sheet
timecrate verify-key                             # can THIS machine read the newest kit?
```

`import-key` checks the file in a throwaway keyring before it touches the real one: a public-only
export, a non-RSA key or an expired key is refused with the reason. `verify-key` answers what the
recovery drill does not: the drill proves the escrowed key works, this proves the key on this
machine does. None of these are `sudo` commands — the keyring belongs to the configured user.

`init` refuses to make a new key when the remote already holds kits, and points here instead.

## 1. The operating system

Install the release named in `TIMECRATE-MANIFESTS/os-release.txt` (`uname.txt` records the kernel,
not the release), and create the user whose home the kit carries.

## 2. Get the kit and extract it for review

```sh
sudo timecrate restore <timestamp>                 # fetch, verify, extract into staging
sudo timecrate restore --local <file.tar.zst.gpg>  # a kit you downloaded yourself
```

Restoring as root with the key imported only into your own keyring fails: `restore` runs as root
and, after the tool's own keyring, uses root's. Import the key with `sudo gpg --import` too, or
use `import-key` as the configured user first.

The kit carries the tool that opens it (`usr/bin/timecrate` and its helpers are in the default
include list), so a machine with no network can still use the extracted copy.

## 3. `/etc`: review before you overwrite

`/etc` belongs to the machine it came from — its disks, mounts, network cards and services.
Restoring it onto the same hardware (or a replacement) is the normal case; laid blindly over
different hardware it can leave the machine unbootable. Reconcile these by hand:

- `etc/fstab`, `etc/crypttab` — check UUIDs against `lsblk -f` / `blkid`, and note any network
  mounts and the credentials they reference.
- `etc/machine-id`, `etc/ssh/ssh_host_*` — keep the old identity or adopt the new one, deliberately.
- `etc/hostname`, `etc/hosts`, `etc/netplan/*`, `etc/NetworkManager/system-connections/`.
- `etc/systemd/system/` — restore the unit files, but on the first boot do not let units that wait
  for mounts or devices start before those exist; boot to `multi-user.target`, or mask them, until
  the hardware is in place, then re-enable them from `TIMECRATE-MANIFESTS/systemd-enabled-*.txt`.
- `etc/passwd`, `shadow`, `group`, `gshadow`, `sudoers*` — merge into the new system's files; do
  not replace them.
- `etc/apt/sources.list.d/*` and their keyrings — restore `usr/share/keyrings/*` and
  `etc/apt/keyrings/*` from the kit too (copies are in `TIMECRATE-MANIFESTS/apt-keyrings/`), or
  `apt update` fails for every third-party repository.

What is safe to lay over any machine: `etc/sysctl.d`, `etc/modprobe.d`, `etc/udev/rules.d`,
`etc/apt/**` and application configuration — additive settings that do not depend on the hardware.
The quarterly capstone proves exactly this subset, including a reboot, on a fresh virtual machine.

## 4. Packages

```sh
M=TIMECRATE-MANIFESTS      # TIMEMACHINE-MANIFESTS in a kit written before 3.0.0
# Foreign architectures FIRST. Without them one package with an unavailable dependency of
# another architecture makes apt refuse the whole transaction: nothing installs, while the file
# restore looks perfect.
while read -r a; do [ -n "$a" ] && sudo dpkg --add-architecture "$a"; done < "$M/dpkg-foreign-architectures.txt"
sudo apt-get update
# merge-avail is REQUIRED on a fresh machine: without an "available" database,
# --set-selections silently records nothing and dselect-upgrade installs nothing
sudo sh -c 'apt-cache dumpavail | dpkg --merge-avail'
sudo dpkg --set-selections < "$M/dpkg-selections.txt"
sudo apt-get dselect-upgrade
# what could NOT be resolved: packages installed from a file, or from a repository not restored
comm -23 <(sort "$M/apt-manual.txt") <(apt-cache pkgnames | sort)
```

If `dselect-upgrade` reports "InstallPackages was called with broken packages", read the unmet
dependency it names: it is almost always a missing foreign architecture, or a package whose
repository has not been restored. Snaps and Flatpaks are listed in `snap-list.txt` and
`flatpak-list.txt`; pipx, pip and npm globals in their own files.

## 5. Desktop and services

```sh
dconf load / < "$M/dconf.ini"          # as the user: desktop settings, enabled extensions
crontab "$M/user-crontab.txt"          # as the user
sudo crontab "$M/root-crontab.txt"
```

Unit files came back with `/etc` and `~/.config/systemd/user`; compare
`systemd-enabled-system.txt` and `systemd-enabled-user.txt` and enable what should run.

## 6. The home directory

Restore the user's home from the kit. The rclone configuration is deliberately never in a kit —
its token could delete every other kit — so connect the remote again:

```sh
timecrate remote connect
```

## 7. Timecrate itself

Install the package again (or use the copy extracted from the kit), then bring back the keys
(step 0). With the recipient in place, `init` keeps the encryption key and makes only a new
signing key — the old signing secret died with the machine, by design:

```sh
timecrate init                         # as the user: keeps the encryption key, adds a signing key
```

Keep the new signing public key with the escrow copies (`timecrate escrow-doc` writes a fresh
sheet). To restore a kit signed by the OLD signing key, import that old public key from the sheet
and name it for that one restore:
`sudo TIMECRATE_EXPECT_SIGNER=<old fingerprint> timecrate restore <timestamp>`.

The package enables the timers when it is installed. Prove the whole loop before trusting it:

```sh
timecrate schedule
sudo timecrate backup --no-upload      # fails loudly if the configuration is wrong
sudo timecrate recovery-drill && sudo timecrate escrow-confirm
```

## Not in the kit

Whatever the include list does not name — media, virtual machine images, caches, anything
re-downloadable. `timecrate coverage` lists what nothing covers, before you need it.
