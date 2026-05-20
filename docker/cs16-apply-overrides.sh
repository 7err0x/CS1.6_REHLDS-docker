#!/usr/bin/env bash
# Seed / overlay AMXX configs on the writable configs volume (see compose cs16_amx_configs).
set -euo pipefail

BASE="${CS16_CSTRIKE_BASE:-/opt/steam/hlds/cstrike-base}"
LIVE="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}"
SRC="${CS16_OVERRIDES_MOUNT:-/mnt/cs16-overrides}"
CFG="$LIVE/addons/amxmodx/configs"

mkdir -p "$CFG"

if [[ ! -f "$CFG/amxx.cfg" && -d "$BASE/addons/amxmodx/configs" ]]; then
	cp -a "$BASE/addons/amxmodx/configs/." "$CFG/"
fi

[[ -d "$SRC" ]] || exit 0

if [[ -f "$SRC/amxmodx/users.ini" ]]; then
	install -m0644 "$SRC/amxmodx/users.ini" "$CFG/users.ini"
fi

if [[ -f "$SRC/amxmodx/plugins.ini" ]]; then
	install -m0644 "$SRC/amxmodx/plugins.ini" "$CFG/plugins.ini"
fi
