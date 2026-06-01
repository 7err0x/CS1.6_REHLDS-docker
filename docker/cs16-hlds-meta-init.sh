#!/usr/bin/env bash
# Ensure HLDS meta cfg files exist as files inside cs16-hlds-meta (not directories).
set -euo pipefail

META="${CS16_HLDS_META_DIR:-/var/cs16/hlds-meta}"
CSTRIKE="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}"
SEED="${CS16_CSTRIKE_SEED:-/usr/local/share/cs16-seed/cstrike-full}"

mkdir -p "$META"

for cfg in banned.cfg listip.cfg config.cfg; do
	target="${META}/${cfg}"
	if [[ -f "$target" ]]; then
		continue
	fi
	if [[ -d "$target" ]]; then
		echo "[cs16-meta-init] removing invalid directory ${target}" >&2
		rm -rf "$target"
	fi
	if [[ -f "${CSTRIKE}/${cfg}" ]]; then
		cp "${CSTRIKE}/${cfg}" "$target"
	elif [[ -f "${SEED}/${cfg}" ]]; then
		cp "${SEED}/${cfg}" "$target"
	else
		: >"$target"
	fi
done

chown -R steam:steam "$META"
