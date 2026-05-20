#!/usr/bin/env bash
# Populate writable /opt/steam/hlds/cstrike (volume) from read-only cstrike-base; copy .wad files.
set -euo pipefail

BASE="${CS16_CSTRIKE_BASE:-/opt/steam/hlds/cstrike-base}"
LIVE="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}"
WRITABLE="${CS16_WRITABLE_ROOT:-/opt/steam/hlds/cstrike-writable}"

mkdir -p "$LIVE"

# Repair broken addons/ trees from older layouts.
if [[ -L "$LIVE/addons/addons" ]]; then
	rm -rf "$LIVE/addons"
fi

link_addons() {
	mkdir -p "$LIVE/addons/amxmodx"
	for item in "$BASE/addons"/*; do
		[[ -e "$item" ]] || continue
		name=$(basename "$item")
		[[ "$name" == "amxmodx" ]] && continue
		target="$LIVE/addons/$name"
		[[ -e "$target" ]] || ln -sfn "$item" "$target"
	done
	for item in "$BASE/addons/amxmodx"/*; do
		[[ -e "$item" ]] || continue
		name=$(basename "$item")
		[[ "$name" == "configs" ]] && continue
		target="$LIVE/addons/amxmodx/$name"
		[[ -e "$target" ]] || ln -sfn "$item" "$target"
	done
}

if [[ ! -f "$LIVE/.cs16-assembled" ]]; then
	for item in "$BASE"/*; do
		[[ -e "$item" ]] || continue
		name=$(basename "$item")
		case "${name,,}" in
			maps | sound | models | sprites | logs | config | addons) continue ;;
			config.cfg | banned.cfg | listip.cfg | reunion.cfg) continue ;;
			*.wad) continue ;;
		esac
		if [[ -e "$LIVE/$name" ]]; then
			continue
		fi
		ln -sfn "$item" "$LIVE/$name"
	done
	touch "$LIVE/.cs16-assembled"
fi

link_addons

install_wad() {
	local src=$1
	local dest="$LIVE/$(basename "$src")"
	[[ -f "$src" ]] || return 0
	install -m0644 "$src" "$dest"
}

while IFS= read -r -d '' w; do
	install_wad "$w"
done < <(find "$BASE" -maxdepth 1 -type f \( -iname '*.wad' \) -print0 2>/dev/null)

if [[ -d "$WRITABLE/wads" ]]; then
	while IFS= read -r -d '' w; do
		install_wad "$w"
	done < <(find "$WRITABLE/wads" -type f \( -iname '*.wad' \) -print0 2>/dev/null)
fi

echo "cstrike ready ($(find "$LIVE" -maxdepth 1 -type f -iname '*.wad' 2>/dev/null | wc -l) wad files in root)"
