#!/usr/bin/env bash
# Merge host-downloaded mods from /mnt/cs16-game-assets into HLDS cstrike layout (runtime).
set -euo pipefail

CSTRIKE="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}"
SRC="${CS16_GAME_ASSETS_MOUNT:-/mnt/cs16-game-assets}"

if [[ ! -d "$SRC" ]]; then
	exit 0
fi

mkdir -p "$CSTRIKE/maps" "$CSTRIKE/sound" "$CSTRIKE/models" "$CSTRIKE/sprites"

if [[ -d "$SRC/maps" ]]; then
	while IFS= read -r -d '' f; do
		cp -af "$f" "$CSTRIKE/maps/"
	done < <(find "$SRC/maps" -maxdepth 1 -type f \( -iname '*.bsp' \) -print0)
fi

if [[ -d "$SRC/sound" ]]; then
	mkdir -p "$CSTRIKE/sound"
	cp -af "$SRC/sound/." "$CSTRIKE/sound/"
fi

if [[ -d "$SRC/models" ]]; then
	mkdir -p "$CSTRIKE/models"
	cp -af "$SRC/models/." "$CSTRIKE/models/"
fi

if [[ -d "$SRC/sprites" ]]; then
	mkdir -p "$CSTRIKE/sprites"
	cp -af "$SRC/sprites/." "$CSTRIKE/sprites/"
fi

if [[ -d "$SRC/wads" ]]; then
	mkdir -p "$CSTRIKE/wads"
	while IFS= read -r -d '' w; do
		cp -af "$w" "$CSTRIKE/wads/"
	done < <(find "$SRC/wads" -maxdepth 1 -type f \( -iname '*.wad' \) -print0)
fi

while IFS= read -r -d '' w; do
	mkdir -p "$CSTRIKE/wads"
	cp -af "$w" "$CSTRIKE/wads/"
done < <(find "$SRC" -maxdepth 1 -type f \( -iname '*.wad' \) -print0)
