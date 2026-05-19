#!/usr/bin/env bash
set -euo pipefail
if [[ "${CS16_SKIP_MERGE_GAME_ASSETS:-0}" != "1" ]]; then
	/usr/local/sbin/cs16-merge-game-assets.sh
fi
exec "$@"
