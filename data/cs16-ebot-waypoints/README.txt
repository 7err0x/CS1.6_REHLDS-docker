E-BOT waypoints for cs16-biohazard (git-tracked, shared with production).

Layout (matches addons/ebot/waypoints/ inside HLDS):
  <map>.ewp              — waypoint graph per map
  matrix/<map>.emt       — precomputed distance matrix (one-time bake per map)

Production mounts this folder read-only at /mnt/cs16-ebot-waypoints.
Dev bake writes here via the ebot-waypoints compose profile.

Bake / refresh (requires game BSPs in data/cs16-game-assets/maps/):
  podman compose -f docker-compose.yml -f docker-compose.ebot-waypoints.yml \
    --profile ebot-waypoints build cs16-biohazard
  EBOT_BAKE_MAP_TIMEOUT_SECS=1800 podman compose -f docker-compose.yml -f docker-compose.ebot-waypoints.yml \
    --profile ebot-waypoints run --rm ebot-waypoints-bake

After baking, commit new .ewp and matrix/*.emt files to git.
