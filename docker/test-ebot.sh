#!/usr/bin/env bash
# Smoke-test E-BOT on cs16-biohazard: build image, start server, check Metamod/E-BOT in logs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

COMPOSE=(docker compose --profile biohazard)
SERVICE=cs16-biohazard
CONTAINER=cs16-biohazard0
WAIT_SECS="${EBOT_TEST_WAIT_SECS:-90}"

echo "[test-ebot] Building ${SERVICE}..."
"${COMPOSE[@]}" build "$SERVICE"

echo "[test-ebot] Starting state-init + ${SERVICE}..."
"${COMPOSE[@]}" up -d cs16-state-init "$SERVICE"

cleanup() {
	"${COMPOSE[@]}" stop "$SERVICE" 2>/dev/null || true
}
trap cleanup EXIT

echo "[test-ebot] Waiting ${WAIT_SECS}s for HLDS + plugins..."
sleep "$WAIT_SECS"

LOGS="$(docker logs "$CONTAINER" 2>&1 || true)"

fail() {
	echo "[test-ebot] FAIL: $1"
	echo "--- last 80 log lines ---"
	echo "$LOGS" | tail -80
	exit 1
}

echo "$LOGS" | rg -qi "ebot|e-bot" || fail "no E-BOT mention in server log"
echo "$LOGS" | rg -qi "Metamod|metamod" || fail "no Metamod mention in server log"
echo "$LOGS" | rg -qi "AMX Mod X|amxmodx" || fail "no AMXX mention in server log"

if echo "$LOGS" | rg -qi "segfault|segmentation fault|fatal error|couldn't load|badf load"; then
	fail "crash or plugin load error in log"
fi

IMG="$("${COMPOSE[@]}" images -q "$SERVICE" | head -1)"
[[ -n "$IMG" ]] || fail "no image id for ${SERVICE}"
INI="$(docker run --rm --entrypoint cat "$IMG" /opt/steam/hlds/cstrike/addons/metamod/plugins.ini)"
echo "$INI" | rg -q "ebot.so" || fail "ebot.so missing from plugins.ini in image"

WP_LINK="$(docker run --rm --entrypoint readlink "$IMG" /opt/steam/hlds/cstrike/addons/ebot/waypoints)"
[[ "$WP_LINK" == "/var/cs16/state/ebot-waypoints" ]] \
	|| fail "addons/ebot/waypoints not linked to cs16-state (got: ${WP_LINK:-<missing>})"

echo "[test-ebot] PASS: E-BOT present in image and server log."
