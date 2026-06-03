#!/usr/bin/env bash
# Stateful egress filter for cs16-biohazard: allow replies to inbound game/RCON traffic,
# drop new outbound connections to the internet.
#
# Requires root (iptables). Run after the container is up so its IP can be resolved.
#
# Usage:
#   sudo ./docker/biohazard-egress-firewall.sh apply
#   sudo ./docker/biohazard-egress-firewall.sh remove
#   sudo ./docker/biohazard-egress-firewall.sh status
#
# Environment (optional):
#   CS16_BIOHAZARD_CONTAINER   default: cs16-biohazard0
#   CS16_BIOHAZARD_DOCKER_NET  default: cs16-internal-network
#   CS16_EGRESS_STATE_FILE     default: /var/run/cs16-biohazard-egress.state

set -euo pipefail

CONTAINER_NAME="${CS16_BIOHAZARD_CONTAINER:-cs16-biohazard0}"
DOCKER_NET="${CS16_BIOHAZARD_DOCKER_NET:-cs16-internal-network}"
STATE_FILE="${CS16_EGRESS_STATE_FILE:-/var/run/cs16-biohazard-egress.state}"
CHAIN="CS16-BIOHAZARD-EGRESS"
IPTABLES=(iptables)

usage() {
	sed -n '2,12p' "$0" | tail -n +2
	exit "${1:-0}"
}

require_root() {
	if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
		echo "error: run as root (sudo $0 $*)" >&2
		exit 1
	fi
}

require_iptables() {
	if ! command -v iptables >/dev/null 2>&1; then
		echo "error: iptables not found" >&2
		exit 1
	fi
}

container_ip() {
	docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME" 2>/dev/null \
		| awk 'NF { print; exit }'
}

docker_subnets() {
	docker network inspect "$DOCKER_NET" -f '{{range .IPAM.Config}}{{.Subnet}}{{"\n"}}{{end}}' 2>/dev/null \
		| awk 'NF'
}

ensure_docker_user_chain() {
	if ! "${IPTABLES[@]}" -nL DOCKER-USER >/dev/null 2>&1; then
		echo "error: DOCKER-USER chain missing — is Docker running?" >&2
		exit 1
	fi
}

chain_exists() {
	"${IPTABLES[@]}" -nL "$CHAIN" >/dev/null 2>&1
}

jump_rule_present() {
	local ip="$1"
	"${IPTABLES[@]}" -C DOCKER-USER -s "$ip" -j "$CHAIN" >/dev/null 2>&1
}

write_state() {
	local ip="$1"
	cat >"$STATE_FILE" <<EOF
CONTAINER_NAME=$CONTAINER_NAME
CONTAINER_IP=$ip
CHAIN=$CHAIN
EOF
	chmod 600 "$STATE_FILE"
}

read_state() {
	# shellcheck disable=SC1090
	[[ -f "$STATE_FILE" ]] && source "$STATE_FILE"
}

apply_chain_rules() {
	local ip="$1"

	"${IPTABLES[@]}" -F "$CHAIN"

	# Replies to client connections (game UDP/TCP, RCON).
	"${IPTABLES[@]}" -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

	# Same Docker network (embedded DNS, other containers on the internal net).
	while IFS= read -r subnet; do
		[[ -n "$subnet" ]] || continue
		"${IPTABLES[@]}" -A "$CHAIN" -d "$subnet" -j ACCEPT
	done < <(docker_subnets)

	# Block new outbound to anywhere else.
	"${IPTABLES[@]}" -A "$CHAIN" -s "$ip" -m conntrack --ctstate NEW,INVALID -j DROP
	"${IPTABLES[@]}" -A "$CHAIN" -s "$ip" -j DROP
}

apply() {
	require_root
	require_iptables
	ensure_docker_user_chain

	local ip
	ip="$(container_ip)"
	if [[ -z "$ip" ]]; then
		echo "error: container '$CONTAINER_NAME' not running or has no IP" >&2
		echo "hint: docker compose --profile biohazard up -d cs16-biohazard" >&2
		exit 1
	fi

	if ! chain_exists; then
		"${IPTABLES[@]}" -N "$CHAIN"
	fi

	apply_chain_rules "$ip"

	if ! jump_rule_present "$ip"; then
		"${IPTABLES[@]}" -I DOCKER-USER 1 -s "$ip" -j "$CHAIN"
	fi

	write_state "$ip"
	echo "applied egress filter for $CONTAINER_NAME ($ip) via chain $CHAIN"
	echo "state: $STATE_FILE"
}

remove_jump() {
	local ip="$1"
	if jump_rule_present "$ip"; then
		"${IPTABLES[@]}" -D DOCKER-USER -s "$ip" -j "$CHAIN"
	fi
}

remove() {
	require_root
	require_iptables

	read_state
	local ip="${CONTAINER_IP:-}"
	if [[ -z "$ip" ]]; then
		ip="$(container_ip)"
	fi

	if [[ -n "$ip" ]]; then
		remove_jump "$ip"
	fi

	if chain_exists; then
		"${IPTABLES[@]}" -F "$CHAIN"
		"${IPTABLES[@]}" -X "$CHAIN"
	fi

	rm -f "$STATE_FILE"
	echo "removed egress filter (chain $CHAIN)"
}

status() {
	require_iptables

	local ip
	ip="$(container_ip)"
	echo "container: $CONTAINER_NAME"
	echo "ip:        ${ip:-<not running>}"
	echo "docker net: $DOCKER_NET"
	echo "chain:     $CHAIN"
	echo "state:     $STATE_FILE"
	if [[ -f "$STATE_FILE" ]]; then
		echo "--- last apply ($STATE_FILE) ---"
		cat "$STATE_FILE"
	fi
	echo "--- DOCKER-USER (matching $CHAIN) ---"
	"${IPTABLES[@]}" -S DOCKER-USER 2>/dev/null | grep -F "$CHAIN" || true
	if chain_exists; then
		echo "--- $CHAIN ---"
		"${IPTABLES[@]}" -S "$CHAIN"
	else
		echo "chain $CHAIN: not present"
	fi
}

main() {
	case "${1:-}" in
	apply) apply ;;
	remove) remove ;;
	status) status ;;
	-h | --help | help) usage 0 ;;
	*)
		echo "usage: $0 {apply|remove|status}" >&2
		exit 1
		;;
	esac
}

main "$@"
