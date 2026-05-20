#!/usr/bin/env bash
# Seed named volumes from /usr/share/cs16/seed (read_only root + cap_drop).
set -euo pipefail

CSTRIKE="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}"
SEED="${CS16_SEED_ROOT:-/usr/share/cs16/seed}"
WRITABLE="${CS16_WRITABLE_ROOT:-/opt/steam/hlds/cstrike-writable}"

mkdir -p "$WRITABLE/wads"
chmod 0777 "$WRITABLE" "$WRITABLE/wads" 2>/dev/null || true

seed_dir() {
	local name=$1
	local dest="$CSTRIKE/$name"
	local src="$SEED/$name"
	[[ -d "$src" ]] || return 0
	mkdir -p "$dest"
	if [[ ! -f "$dest/.cs16-seeded" ]]; then
		cp -a "$src/." "$dest/"
		touch "$dest/.cs16-seeded"
	fi
}

for d in maps sound models sprites; do
	seed_dir "$d"
done

if [[ -d "$SEED/wads" ]]; then
	mkdir -p "$WRITABLE/wads"
	if [[ ! -f "$WRITABLE/wads/.cs16-seeded" ]]; then
		cp -a "$SEED/wads/." "$WRITABLE/wads/"
		touch "$WRITABLE/wads/.cs16-seeded"
	fi
fi
