FastDL is served by the Docker image built from docker/fastdl/Dockerfile.
It copies from the SAME game image tag (CS16_IMAGE_NAME / cs16-respawn:latest):
  maps/  models/  sound/  sprites/  gfx/  resource/  overviews/  (if present)
  plus *.wad in cstrike root (e.g. de_vegas.wad).

No manual copy into this folder is required for content baked into the game image.

Workflow:
  1. docker compose build cs16          # or: build --no-cache after map/mod Dockerfile changes
  2. docker compose build fastdl        # refreshes FastDL from that image
  3. docker compose --profile fastdl up -d
  4. Set sv_downloadurl in cstrike/config/fastdl.cfg (e.g. http://LAN_IP:8080/)

Requires Docker BuildKit (default on recent Docker): RUN --mount=from=game ...

Optional: bind-mount extra files by adding a volume in docker-compose.yml under fastdl
(read-only) and extending docker/fastdl/default.conf — not set up by default.
