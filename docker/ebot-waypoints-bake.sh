#!/usr/bin/env bash
# Bake E-BOT .ewp + matrix/*.emt for every map in mapcycle.biohazard.txt.
set -euo pipefail

CSTRIKE="${CSTRIKE_ROOT:-/opt/steam/hlds/cstrike}"
WP_DIR="${CS16_EBOT_WAYPOINTS_MOUNT:-/mnt/cs16-ebot-waypoints}"
MAPCYCLE="${CS16_EBOT_WAYPOINTS_MAPCYCLE:-${CSTRIKE}/mapcycle.biohazard.txt}"
GAME_ASSETS="${CS16_GAME_ASSETS_MOUNT:-/mnt/cs16-game-assets}"
RCON="${EBOT_BAKE_RCON_PASSWORD:-${BIOHAZARD_RCON_PASSWORD:-changeme}}"
MAP_TIMEOUT="${EBOT_BAKE_MAP_TIMEOUT_SECS:-1800}"
PORT="${EBOT_BAKE_PORT:-27018}"
LOG_DIR="${CSTRIKE}/logs"
FATAL_LIMIT="${EBOT_BAKE_FATAL_LIMIT:-2}"

mkdir -p "${WP_DIR}/matrix" "${LOG_DIR}"

parse_mapcycle() {
	grep -vE '^\s*(//|#|$)' "$MAPCYCLE" | awk '{print $1}'
}

map_ready() {
	local map=$1
	[[ -s "${WP_DIR}/${map}.ewp" && -s "${WP_DIR}/matrix/${map}.emt" ]]
}

map_bsp_present() {
	local map=$1
	[[ -f "${CSTRIKE}/maps/${map}.bsp" ]] \
		|| [[ -f "${GAME_ASSETS}/maps/${map}.bsp" ]]
}

rcon_send() {
	local cmd=$1
	# GoldSrc RCON over UDP (server listens on game port).
	printf '\xFF\xFF\xFF\xFFrcon %s %s' "$RCON" "$cmd" >/dev/udp/127.0.0.1/$PORT
}

apply_bake_cvars() {
	local tries=0
	while ((tries < 30)); do
		if rcon_send "status" 2>/dev/null; then
			break
		fi
		sleep 2
		tries=$((tries + 1))
	done
	rcon_send "ebot_analyze_grid_distance 128"
	rcon_send "ebot_analyze_auto_start 1"
	rcon_send "ebot_quota 4"
	rcon_send "ebot_keep_slots 0"
	rcon_send "ebot_stop_bots 0"
	rcon_send "ebot_zp_delay_custom 0"
	rcon_send "mp_timelimit 5"
	rcon_send "mp_roundtime 2"
	rcon_send "mp_freezetime 0"
}

wait_for_map_files() {
	local map=$1 pid=$2
	local ewp="${WP_DIR}/${map}.ewp"
	local emt="${WP_DIR}/matrix/${map}.emt"
	local deadline=$((SECONDS + MAP_TIMEOUT))
	local log_file=""
	local fatals=0
	local cvars_applied=0
	local started=$SECONDS

	while ((SECONDS < deadline)); do
		if ! kill -0 "$pid" 2>/dev/null; then
			echo "[ebot-waypoints-bake] WARN: HLDS exited for ${map}" >&2
			return 1
		fi

		if [[ "$cvars_applied" -eq 0 && $((SECONDS - started)) -ge 20 ]]; then
			apply_bake_cvars
			cvars_applied=1
		fi

		log_file=$(find "$LOG_DIR" -maxdepth 1 -name 'L*.log' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
		if [[ -n "$log_file" && -f "$log_file" ]]; then
			fatals=$(grep -c "FATAL ERROR" "$log_file" 2>/dev/null || true)
			if [[ "$fatals" -ge "$FATAL_LIMIT" ]]; then
				grep "FATAL ERROR" "$log_file" | tail -1 >&2 || true
				echo "[ebot-waypoints-bake] ERROR: map load failure for ${map} (missing WAD/BSP? see ${log_file})" >&2
				return 1
			fi
			if grep -qE "Distance Matrix loaded from the file\\.|Distance matrix loaded" "$log_file" 2>/dev/null; then
				[[ -s "$emt" ]] && return 0
			fi
		fi

		if [[ -s "$ewp" && -s "$emt" ]]; then
			return 0
		fi
		sleep 2
	done

	echo "[ebot-waypoints-bake] TIMEOUT ${map} after ${MAP_TIMEOUT}s (ewp=$([[ -s $ewp ]] && echo yes || echo no) emt=$([[ -s $emt ]] && echo yes || echo no))" >&2
	return 1
}

stop_hlds() {
	local pid=$1
	kill -TERM "$pid" 2>/dev/null || true
	for _ in $(seq 1 15); do
		kill -0 "$pid" 2>/dev/null || return 0
		sleep 1
	done
	kill -KILL "$pid" 2>/dev/null || true
	wait "$pid" 2>/dev/null || true
}

bake_map() {
	local map=$1
	echo "[ebot-waypoints-bake] === ${map} ==="

	if map_ready "$map"; then
		echo "[ebot-waypoints-bake] skip ${map} (.ewp + matrix already present)"
		return 0
	fi

	if ! map_bsp_present "$map"; then
		echo "[ebot-waypoints-bake] ERROR: missing BSP for ${map} (sync data/cs16-game-assets/maps/ first)" >&2
		return 1
	fi

	find "$LOG_DIR" -maxdepth 1 -name 'L*.log' -delete 2>/dev/null || true

	./hlds_run -norestart \
		-timeout 5 \
		-pingboost 1 \
		-game cstrike \
		+servercfgfile config/server-ebot-bake.cfg \
		+exec config/gamemode-biohazard.cfg \
		+maxplayers 8 \
		+rcon_password "$RCON" \
		+hostname "E-BOT Waypoint Bake" \
		+sv_lan 1 \
		+mp_timelimit 5 \
		+mp_roundtime 2 \
		+mp_freezetime 0 \
		+log on \
		+map "$map" \
		+port "$PORT" &
	local pid=$!
	disown "$pid" 2>/dev/null || true

	if wait_for_map_files "$map" "$pid"; then
		echo "[ebot-waypoints-bake] OK ${map}"
		stop_hlds "$pid"
		return 0
	fi

	stop_hlds "$pid"
	return 1
}

cd "${HLDS_ROOT:-/opt/steam/hlds}"

failed=0
baked=0
skipped=0
maps=()
mapfile -t maps < <(parse_mapcycle)

for map in "${maps[@]}"; do
	[[ -n "$map" ]] || continue
	if map_ready "$map"; then
		echo "[ebot-waypoints-bake] skip ${map}"
		skipped=$((skipped + 1))
		continue
	fi
	if bake_map "$map"; then
		baked=$((baked + 1))
	else
		failed=$((failed + 1))
	fi
	sleep 2
done

echo "[ebot-waypoints-bake] finished: baked=${baked} skipped=${skipped} failed=${failed}"
echo "[ebot-waypoints-bake] output: ${WP_DIR}/ and ${WP_DIR}/matrix/"
[[ "$failed" -eq 0 ]]
