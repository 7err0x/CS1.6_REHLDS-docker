Runtime-writable HLDS files (bind-mounted into the game container).

- config.cfg, banned.cfg, listip.cfg — HLDS / ReUnion update these at runtime.
- wads/ — optional .wad copies + symlinks into cstrike/ (see docker/cs16-runtime-setup.sh).

If you see "Permission denied" on first start (common on Fedora + SELinux), run once from the repo root:

  mkdir -p data/cs16-state/wads
  chmod -R a+rwX data/cs16-state data/cs16-logs

Compose mounts use the :z suffix for SELinux volume relabeling.
