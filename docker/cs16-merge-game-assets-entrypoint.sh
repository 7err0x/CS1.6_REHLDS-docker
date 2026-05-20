#!/usr/bin/env bash
set -euo pipefail

run_setup() {
	if [[ "${CS16_SKIP_RUNTIME_SETUP:-0}" != "1" ]]; then
		/usr/local/sbin/cs16-runtime-setup.sh
	fi
	if [[ "${CS16_SKIP_MERGE_GAME_ASSETS:-0}" != "1" ]]; then
		/usr/local/sbin/cs16-merge-game-assets.sh
	fi
	/usr/local/sbin/cs16-assemble-cstrike.sh
	/usr/local/sbin/cs16-apply-overrides.sh
	chown -R steam:steam \
		/opt/steam/hlds/cstrike-writable \
		/opt/steam/hlds/cstrike \
		/opt/steam/hlds/cstrike/maps \
		/opt/steam/hlds/cstrike/sound \
		/opt/steam/hlds/cstrike/models \
		/opt/steam/hlds/cstrike/sprites \
		/opt/steam/hlds/cstrike/logs \
		/opt/steam/hlds/cstrike/addons/amxmodx/configs \
		2>/dev/null || true
}

if [[ "$(id -u)" -eq 0 ]]; then
	run_setup
	exec setpriv --reuid=steam --regid=steam --clear-groups -- "$@"
fi

run_setup
exec "$@"
