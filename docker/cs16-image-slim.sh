#!/usr/bin/env bash
# Shrink the cs16 image: bootstrap once for state-init, strip volume-backed assets and HLDS bloat.
set -euo pipefail

HLDS="${HLDS_ROOT:-/opt/steam/hlds}"
CSTRIKE="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}"
VALVE="${HLDS}/valve"
BOOT="${CS16_BOOTSTRAP_ROOT:-/usr/local/share/cs16-bootstrap}"
STEAM_HOME="${STEAM_HOME:-/opt/steam}"

echo "[cs16-image-slim] Building cs16-bootstrap (single copy for state-init)..."
mkdir -p "${BOOT}"
for d in maps sound models sprites; do
	if [[ -d "${CSTRIKE}/${d}" ]]; then
		mkdir -p "${BOOT}/${d}"
		cp -a "${CSTRIKE}/${d}/." "${BOOT}/${d}/"
	fi
done
mkdir -p "${BOOT}/wads"
find "${CSTRIKE}" -maxdepth 1 -type f -iname '*.wad' -exec cp -a {} "${BOOT}/wads/" \;
if [[ -d "${CSTRIKE}/wads" ]]; then
	cp -a "${CSTRIKE}/wads/." "${BOOT}/wads/" 2>/dev/null || true
fi
if [[ -d "${CSTRIKE}/addons/amxmodx/data" ]]; then
	mkdir -p "${BOOT}/amxx-data"
	cp -a "${CSTRIKE}/addons/amxmodx/data/." "${BOOT}/amxx-data/"
fi

echo "[cs16-image-slim] Stripping unused valve/ content..."
rm -rf \
	"${VALVE}/maps" \
	"${VALVE}/media" \
	"${VALVE}/overviews" \
	"${VALVE}/sound"

echo "[cs16-image-slim] Removing volume-backed cstrike assets from image..."
for d in maps sound models sprites; do
	if [[ -d "${CSTRIKE}/${d}" ]]; then
		find "${CSTRIKE}/${d}" -mindepth 1 -delete
	fi
done
if [[ -d "${CSTRIKE}/wads" ]]; then
	find "${CSTRIKE}/wads" -mindepth 1 -delete
fi
# Keep lang/gamedata in the image; only vault is persisted on the cs16-state volume.
if [[ -d "${CSTRIKE}/addons/amxmodx/data/vault" ]]; then
	find "${CSTRIKE}/addons/amxmodx/data/vault" -mindepth 1 -delete
fi

echo "[cs16-image-slim] Removing AMXX build artifacts..."
rm -rf "${CSTRIKE}/addons/amxmodx/scripting"

echo "[cs16-image-slim] Removing SteamCMD / 64-bit HLDS artifacts..."
rm -rf \
	"${STEAM_HOME}/package" \
	"${STEAM_HOME}/steamcmd" \
	"${STEAM_HOME}/steamcmd.sh" \
	"${STEAM_HOME}/.steam" \
	"${HLDS}/linux64"

echo "[cs16-image-slim] Done."
