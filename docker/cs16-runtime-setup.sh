#!/usr/bin/env bash
# Prepare writable runtime paths (named Docker volumes; runs as steam).
set -euo pipefail

CSTRIKE="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}"
SEED="${CS16_CSTRIKE_SEED:-/usr/local/share/cs16-seed/cstrike-full}"
STEAM_HOME="${HOME:-/opt/steam}/.steam"

seed_if_empty() {
	local rel=$1
	local dest="${CSTRIKE}/${rel}"
	local src="${SEED}/${rel}"
	local marker="${dest}/.seeded-from-image"

	[[ -d "$src" ]] || return 0
	mkdir -p "$dest"

	if [[ -n "$(find "$dest" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
		return 0
	fi

	echo "[cs16-runtime-setup] Seeding cstrike/${rel} (first start only)..."
	tar -C "$src" -cf - . | tar -C "$dest" --no-same-owner --no-same-permissions -xf -
	touch "$marker"
}

touch_if_missing() {
	local path=$1
	[[ -e "$path" ]] || : >"$path"
}

mkdir -p "${STEAM_HOME}" \
	"${CSTRIKE}/logs" \
	"${CSTRIKE}/addons/amxmodx/data" \
	"${CSTRIKE}/maps" \
	"${CSTRIKE}/sound" \
	"${CSTRIKE}/models" \
	"${CSTRIKE}/sprites" \
	"${CSTRIKE}/wads"

if [[ ! -e "${STEAM_HOME}/sdk32" ]]; then
	ln -sf /opt/steam/linux32 "${STEAM_HOME}/sdk32"
fi

for subdir in maps sound models sprites; do
	seed_if_empty "$subdir"
done

AMXX_DATA="${CSTRIKE}/addons/amxmodx/data"
if [[ -d "${SEED}/addons/amxmodx/data" && ! -f "${AMXX_DATA}/.seeded-from-image" ]]; then
	if [[ -z "$(find "$AMXX_DATA" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
		echo "[cs16-runtime-setup] Seeding addons/amxmodx/data (first start only)..."
		tar -C "${SEED}/addons/amxmodx/data" -cf - . \
			| tar -C "$AMXX_DATA" --no-same-owner --no-same-permissions -xf -
		touch "${AMXX_DATA}/.seeded-from-image"
	fi
fi
