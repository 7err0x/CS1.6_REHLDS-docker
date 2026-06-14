#!/usr/bin/env bash
# Seed cs16-state volume (dirs, HLDS meta cfg files, default assets). Runs as root once before HLDS.
set -euo pipefail

STATE="${CS16_STATE_DIR:-/var/cs16/state}"
BOOTSTRAP="${CS16_BOOTSTRAP_ROOT:-/usr/local/share/cs16-bootstrap}"
CSTRIKE="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}"

mkdir -p \
	"${STATE}/hlds-meta" \
	"${STATE}/hlds-meta-respawn" \
	"${STATE}/hlds-meta-biohazard" \
	"${STATE}/amxx-data-respawn/vault" \
	"${STATE}/amxx-data-biohazard/vault" \
	"${STATE}/amxx-data" \
	"${STATE}/maps" \
	"${STATE}/sound" \
	"${STATE}/models" \
	"${STATE}/sprites" \
	"${STATE}/wads" \
	"${STATE}/ebot-logs"

seed_dir_from_bootstrap() {
	local name=$1
	local dest="${STATE}/${name}"
	local src="${BOOTSTRAP}/${name}"
	local marker="${dest}/.seeded-from-image"

	[[ -d "$src" ]] || return 0
	if [[ ! -f "$marker" && -z "$(find "$dest" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
		echo "[cs16-state-init] Seeding state/${name} (first start only)..."
		tar -C "$src" -cf - . | tar -C "$dest" --no-same-owner --no-same-permissions -xf -
		touch "$marker"
		return 0
	fi

	echo "[cs16-state-init] Merging missing bootstrap files into state/${name}..."
	while IFS= read -r -d '' f; do
		rel="${f#"$src"/}"
		[[ -e "$dest/$rel" ]] && continue
		install -D -o steam -g steam -m0644 "$f" "$dest/$rel"
	done < <(find "$src" -type f -print0 2>/dev/null)
	touch "$marker"
	chown steam:steam "$marker" 2>/dev/null || true
}

for subdir in maps sound models sprites wads ebot-logs; do
	seed_dir_from_bootstrap "$subdir"
done

seed_amxx_vault() {
	local profile=$1
	local dest="${STATE}/amxx-data-${profile}/vault"
	local src="${BOOTSTRAP}/amxx-data/vault"
	local marker="${dest}/.seeded-from-image"

	[[ -d "$src" ]] || return 0
	if [[ -n "$(find "$dest" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
		return 0
	fi
	echo "[cs16-state-init] Seeding amxx-data-${profile}/vault (first start only)..."
	mkdir -p "$dest"
	tar -C "$src" -cf - . | tar -C "$dest" --no-same-owner --no-same-permissions -xf -
	touch "$marker"
}

for profile in respawn biohazard; do
	seed_amxx_vault "$profile"
done

seed_cfg_file() {
	local target=$1 src=$2
	if [[ -f "$target" ]]; then
		return 0
	fi
	if [[ -d "$target" ]]; then
		echo "[cs16-state-init] removing invalid directory ${target}" >&2
		rm -rf "$target"
	fi
	if [[ -f "$src" ]]; then
		cp "$src" "$target"
	else
		: >"$target"
	fi
	chown steam:steam "$target" 2>/dev/null || true
}

for cfg in banned.cfg listip.cfg config.cfg; do
	seed_cfg_file "${STATE}/hlds-meta/${cfg}" "${BOOTSTRAP}/hlds-meta/${cfg}"
done

for profile in respawn biohazard; do
	seed_cfg_file \
		"${STATE}/hlds-meta-${profile}/config.cfg" \
		"${BOOTSTRAP}/hlds-meta-${profile}/config.cfg"
done

relabel_state_selinux() {
	command -v chcon >/dev/null 2>&1 || return 0
	if chcon -R -h system_u:object_r:container_file_t:s0 "$STATE" 2>/dev/null; then
		return 0
	fi
	echo "[cs16-state-init] warn: partial SELinux relabel on ${STATE}; if HLDS cannot read maps, run: ./docker/fix-volume-selinux.sh" >&2
}

chown_best_effort() {
	local target=$1
	if chown -R steam:steam "$target" 2>/dev/null; then
		return 0
	fi
	# Rootless: files HLDS already wrote keep a different mapped uid; leave them alone.
	echo "[cs16-state-init] warn: partial chown on ${target} (normal on rootless Podman)" >&2
	find "$target" \( -user root -o -uid "$(id -u)" \) -exec chown steam:steam {} + 2>/dev/null || true
}

if [[ -d /host/cs16-logs ]]; then
	mkdir -p /host/cs16-logs/respawn /host/cs16-logs/biohazard
	chown_best_effort /host/cs16-logs
	echo "[cs16-state-init] Host logs: /host/cs16-logs/{respawn,biohazard}"
fi

relabel_state_selinux
chown_best_effort "$STATE"
