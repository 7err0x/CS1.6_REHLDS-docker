#!/usr/bin/env bash
# Seed cs16-state volume (dirs, HLDS meta cfg files, default assets). Runs as root once before HLDS.
set -euo pipefail

STATE="${CS16_STATE_DIR:-/var/cs16/state}"
BOOTSTRAP="${CS16_BOOTSTRAP_ROOT:-/usr/local/share/cs16-bootstrap}"
CSTRIKE="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}"

mkdir -p \
	"${STATE}/hlds-meta" \
	"${STATE}/logs" \
	"${STATE}/amxx-data" \
	"${STATE}/maps" \
	"${STATE}/sound" \
	"${STATE}/models" \
	"${STATE}/sprites" \
	"${STATE}/wads"

seed_dir_if_empty() {
	local name=$1
	local dest="${STATE}/${name}"
	local src="${BOOTSTRAP}/${name}"
	local marker="${dest}/.seeded-from-image"

	[[ -d "$src" ]] || return 0
	if [[ -n "$(find "$dest" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
		return 0
	fi

	echo "[cs16-state-init] Seeding state/${name} (first start only)..."
	tar -C "$src" -cf - . | tar -C "$dest" --no-same-owner --no-same-permissions -xf -
	touch "$marker"
}

for subdir in maps sound models sprites wads amxx-data; do
	seed_dir_if_empty "$subdir"
done

for cfg in banned.cfg listip.cfg config.cfg; do
	target="${STATE}/hlds-meta/${cfg}"
	if [[ -f "$target" ]]; then
		continue
	fi
	if [[ -d "$target" ]]; then
		echo "[cs16-state-init] removing invalid directory ${target}" >&2
		rm -rf "$target"
	fi
	if [[ -f "${CSTRIKE}/${cfg}" ]]; then
		cp "${CSTRIKE}/${cfg}" "$target"
	else
		: >"$target"
	fi
done

chown -R steam:steam "$STATE"
