#!/usr/bin/env bash
# HLDS startup: Steam SDK symlink + merge community assets, then exec the server.
set -euo pipefail

CSTRIKE="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}"
SRC="${CS16_GAME_ASSETS_MOUNT:-/mnt/cs16-game-assets}"
STEAM_HOME="${HOME:-/opt/steam}/.steam"

mkdir -p "${STEAM_HOME}"
if [[ ! -e "${STEAM_HOME}/sdk32" ]]; then
	ln -sf /opt/steam/linux32 "${STEAM_HOME}/sdk32"
fi

if [[ "${CS16_SKIP_MERGE_GAME_ASSETS:-0}" != "1" && -d "$SRC" ]]; then
	mkdir -p "$CSTRIKE/maps" "$CSTRIKE/sound" "$CSTRIKE/models" "$CSTRIKE/sprites" "$CSTRIKE/wads"

	if [[ -d "$SRC/maps" ]]; then
		while IFS= read -r -d '' f; do
			cp -af "$f" "$CSTRIKE/maps/"
		done < <(find "$SRC/maps" -maxdepth 1 -type f \( -iname '*.bsp' \) -print0)
	fi

	if [[ -d "$SRC/sound" ]]; then
		cp -af "$SRC/sound/." "$CSTRIKE/sound/"
	fi

	if [[ -d "$SRC/models" ]]; then
		cp -af "$SRC/models/." "$CSTRIKE/models/"
	fi

	if [[ -d "$SRC/sprites" ]]; then
		cp -af "$SRC/sprites/." "$CSTRIKE/sprites/"
	fi

	if [[ -d "$SRC/wads" ]]; then
		while IFS= read -r -d '' w; do
			cp -af "$w" "$CSTRIKE/wads/"
		done < <(find "$SRC/wads" -maxdepth 1 -type f \( -iname '*.wad' \) -print0)
	fi

	while IFS= read -r -d '' w; do
		cp -af "$w" "$CSTRIKE/wads/"
	done < <(find "$SRC" -maxdepth 1 -type f \( -iname '*.wad' \) -print0)
fi

# Writable state volume masks image-baked sprites; add any pack files missing after an image upgrade.
BOOT="${CS16_BOOTSTRAP_ROOT:-/usr/local/share/cs16-bootstrap}"
if [[ -d "$BOOT/sprites" ]]; then
	mkdir -p "$CSTRIKE/sprites"
	while IFS= read -r -d '' f; do
		base=$(basename "$f")
		[[ -e "$CSTRIKE/sprites/$base" ]] || cp -af "$f" "$CSTRIKE/sprites/$base"
	done < <(find "$BOOT/sprites" -maxdepth 1 -type f -print0)
fi

exec "$@"
