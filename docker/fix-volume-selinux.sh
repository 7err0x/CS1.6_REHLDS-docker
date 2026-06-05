#!/usr/bin/env bash
# One-time fix: game-asset copies used cp -a and kept user_home_t; containers need container_file_t.
set -euo pipefail

VOLUME_NAME="${CS16_STATE_VOLUME:-cs16-rehlds_cs16-state}"

if command -v podman >/dev/null 2>&1; then
	VOLUME_PATH="$(podman volume inspect "$VOLUME_NAME" --format '{{.Mountpoint}}')"
	chcon_cmd=(podman unshare chcon -R -h -t container_file_t)
elif command -v docker >/dev/null 2>&1; then
	VOLUME_PATH="$(docker volume inspect "$VOLUME_NAME" --format '{{.Mountpoint}}')"
	chcon_cmd=(chcon -R -h -t container_file_t)
else
	echo "error: need podman or docker" >&2
	exit 1
fi

if [[ -z "$VOLUME_PATH" || ! -d "$VOLUME_PATH" ]]; then
	echo "error: volume ${VOLUME_NAME} not found" >&2
	exit 1
fi

echo "Relabeling ${VOLUME_PATH} for container access..."
"${chcon_cmd[@]}" "$VOLUME_PATH"
echo "OK"
