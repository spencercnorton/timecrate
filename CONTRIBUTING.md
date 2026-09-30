# Contributing to Timecrate

Thanks for your interest. This is a small project with one maintainer, so the process is
deliberately light.

## How changes land

GitHub is the development home. Branch from `main` and open a pull request into `main`. The checks
must pass before merge. Changes ship in tagged releases.

Use a GitHub noreply address for commit authorship if you prefer to keep your personal address
private. Public history is public data.

## Working on the code

The suites install packages, create users and replace rclone with fakes, so run them as root in a
throwaway `ubuntu:26.04` container, never on your own machine:

```bash
docker run --rm -v "$PWD":/repo:ro ubuntu:26.04 bash /repo/tests/checks.sh
docker run --rm -v "$PWD":/repo:ro ubuntu:26.04 bash /repo/tests/gui-smoke.sh
tests/package.sh       # needs docker: installs and upgrades the packages under systemd
scripts/build.sh       # both .deb packages, into dist/
```

- A change to how kits are written, named, listed or pruned must keep the kits already on people's
  remotes readable — `tests/legacy-kit.sh` writes one the way releases before 3.0.0 did, and T60
  in `tests/checks.sh` holds the line. Add to it rather than around it.
- Keep a change to one concern.
- Commits carry a `Signed-off-by:` line (`git commit -s`, the Developer Certificate of Origin).
  There is no CLA.
- No secrets, hostnames, personal data or personal paths in the diff; the privacy check rejects
  them.

## Out of scope

- Whole-disk images and bare-metal cloning; other tools do that well.
- Any path that extracts a kit before its signature is verified.

## Pull request checklist

- [ ] `tests/checks.sh` and `tests/gui-smoke.sh` pass
- [ ] `tests/package.sh` passes if packaging or a unit changed
- [ ] Commits are signed off
- [ ] `CHANGELOG.md` updated under `## Unreleased` if behaviour changed
