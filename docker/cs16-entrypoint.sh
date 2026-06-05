#!/usr/bin/env bash
# HLDS startup: Steam SDK symlink + merge community assets, then exec the server.
set -euo pipefail

CSTRIKE="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}"
STATE="${CS16_STATE_DIR:-/var/cs16/state}"
SRC="${CS16_GAME_ASSETS_MOUNT:-/mnt/cs16-game-assets}"
STEAM_HOME="${HOME:-/opt/steam}/.steam"

cs16_dir_is_empty() {
	local path=$1
	[[ -d "$path" ]] && [[ -z "$(find "$path" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]
}

cs16_verify_state_links() {
	[[ -d "${STATE}/maps" ]] || return 0
	local state_maps
	state_maps=$(find "${STATE}/maps" -maxdepth 1 -name '*.bsp' 2>/dev/null | wc -l)
	[[ "$state_maps" -gt 0 ]] || return 0

	if [[ -L "${CSTRIKE}/maps" && "$(readlink "${CSTRIKE}/maps")" == "${STATE}/maps" ]]; then
		return 0
	fi

	if cs16_dir_is_empty "${CSTRIKE}/maps" || [[ ! -w "${CSTRIKE}/maps" ]]; then
		echo "[cs16-entrypoint] ERROR: ${STATE}/maps has stock maps but ${CSTRIKE}/maps is empty and not linked." >&2
		echo "[cs16-entrypoint] Rebuild images, then recreate containers:" >&2
		echo "[cs16-entrypoint]   podman compose build cs16 cs16-biohazard" >&2
		echo "[cs16-entrypoint]   podman compose --profile respawn up -d --force-recreate" >&2
		exit 1
	fi
}

cs16_verify_state_links

mkdir -p "${STEAM_HOME}"
if [[ ! -e "${STEAM_HOME}/sdk32" ]]; then
	ln -sf /opt/steam/linux32 "${STEAM_HOME}/sdk32"
fi

if [[ "${CS16_SKIP_MERGE_GAME_ASSETS:-0}" != "1" && -d "$SRC" ]]; then
	mkdir -p "$CSTRIKE/maps" "$CSTRIKE/sound" "$CSTRIKE/models" "$CSTRIKE/sprites" "$CSTRIKE/wads" 2>/dev/null || true

	cs16_copy_file() {
		local f=$1 dest=$2
		[[ -f "$f" && -w "$dest" ]] || return 0
		[[ -L "$f" ]] && return 0
		cp -af "$f" "$dest"
	}

	if [[ -d "$SRC/maps" && -w "$CSTRIKE/maps" ]]; then
		while IFS= read -r -d '' f; do
			cs16_copy_file "$f" "$CSTRIKE/maps/"
		done < <(find "$SRC/maps" -maxdepth 1 -type f \( -iname '*.bsp' \) -print0)
	fi

	if [[ -d "$SRC/sound" && -w "$CSTRIKE/sound" ]]; then
		while IFS= read -r -d '' f; do
			[[ -L "$f" ]] && continue
			install -D -m0644 "$f" "$CSTRIKE/sound/${f#"$SRC/sound/"}"
		done < <(find "$SRC/sound" -type f -print0 2>/dev/null)
	fi

	if [[ -d "$SRC/models" && -w "$CSTRIKE/models" ]]; then
		while IFS= read -r -d '' f; do
			[[ -L "$f" ]] && continue
			install -D -m0644 "$f" "$CSTRIKE/models/${f#"$SRC/models/"}"
		done < <(find "$SRC/models" -type f -print0 2>/dev/null)
	fi

	if [[ -d "$SRC/sprites" && -w "$CSTRIKE/sprites" ]]; then
		while IFS= read -r -d '' f; do
			[[ -L "$f" ]] && continue
			install -D -m0644 "$f" "$CSTRIKE/sprites/${f#"$SRC/sprites/"}"
		done < <(find "$SRC/sprites" -type f -print0 2>/dev/null)
	fi

	if [[ -d "$SRC/wads" && -w "$CSTRIKE/wads" ]]; then
		while IFS= read -r -d '' w; do
			cs16_copy_file "$w" "$CSTRIKE/wads/"
		done < <(find "$SRC/wads" -maxdepth 1 -type f \( -iname '*.wad' \) -print0)
	fi

	if [[ -w "$CSTRIKE/wads" ]]; then
		while IFS= read -r -d '' w; do
			cs16_copy_file "$w" "$CSTRIKE/wads/"
		done < <(find "$SRC" -maxdepth 1 -type f \( -iname '*.wad' \) -print0)
	fi
fi

BOOT="${CS16_BOOTSTRAP_ROOT:-/usr/local/share/cs16-bootstrap}"

# plugins.ini is baked per image (CS16_PLUGINS_INI at build). read_only root cannot overwrite configs/.

# State volume for sprites is writable; skip when rootfs is read-only (e.g. quick test without volumes).
if [[ -d "$BOOT/sprites" && -w "$CSTRIKE/sprites" ]]; then
	mkdir -p "$CSTRIKE/sprites"
	while IFS= read -r -d '' f; do
		base=$(basename "$f")
		[[ -e "$CSTRIKE/sprites/$base" ]] || cp -af "$f" "$CSTRIKE/sprites/$base"
	done < <(find "$BOOT/sprites" -maxdepth 1 -type f -print0)
fi

exec "$@"
