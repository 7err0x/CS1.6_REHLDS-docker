#!/usr/bin/env bash
# Smoke-test cs16-entrypoint.sh on a read-only root (matches compose security).
set -euo pipefail

IMAGE="${CS16_TEST_IMAGE:-cs16-respawn:latest}"
ENTRYPOINT="${CS16_ENTRYPOINT_SCRIPT:-$(dirname "$0")/cs16-entrypoint.sh}"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
	echo "missing image: $IMAGE (run: docker compose build cs16)" >&2
	exit 1
fi

docker run --rm \
	--read-only \
	--user steam \
	--tmpfs /tmp:mode=1777,size=64m \
	--tmpfs /run:mode=755,size=8m \
	--tmpfs /opt/steam/.steam:mode=1777,size=64k \
	-v "${ENTRYPOINT}:/usr/local/sbin/cs16-entrypoint.sh:ro" \
	-e CS16_SKIP_MERGE_GAME_ASSETS=1 \
	"$IMAGE" \
	/usr/local/sbin/cs16-entrypoint.sh /bin/echo "entrypoint read-only OK"

echo "[test-cs16-entrypoint] passed"
