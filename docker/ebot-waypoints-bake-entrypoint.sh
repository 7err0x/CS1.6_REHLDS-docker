#!/usr/bin/env bash
# Root wrapper: fix bind-mount ownership, then run bake as steam.
set -euo pipefail

WP="${CS16_EBOT_WAYPOINTS_MOUNT:-/mnt/cs16-ebot-waypoints}"
LOGS="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}/logs"
AMXX_LOGS="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}/addons/amxmodx/logs"

for dir in "$WP" "${WP}/matrix" "$LOGS" "$AMXX_LOGS"; do
	[[ -d "$dir" ]] || mkdir -p "$dir"
	chown -R steam:steam "$dir" 2>/dev/null || chmod -R a+rwX "$dir" 2>/dev/null || true
done

exec setpriv --reuid=steam --regid=steam --clear-groups --reset-env -- \
	/usr/local/sbin/cs16-entrypoint.sh "$@"
