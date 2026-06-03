#!/usr/bin/env bash
# Install host logrotate policy for ./data/cs16-logs (run manually with sudo).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${CS16_LOG_DIR:-${REPO_ROOT}/data/cs16-logs}"
TEMPLATE="${REPO_ROOT}/docker/logrotate/cs16-hlds.logrotate"
DEST="${CS16_LOGROTATE_DEST:-/etc/logrotate.d/cs16-hlds}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
	echo "error: run as root — sudo $0" >&2
	exit 1
fi

case "$LOG_DIR" in
	/*)
		if [[ "$LOG_DIR" =~ [\|\`\$\;] ]]; then
			echo "error: LOG_DIR contains unsafe characters: $LOG_DIR" >&2
			exit 1
		fi
		;;
	*)
		echo "error: LOG_DIR must be an absolute path: $LOG_DIR" >&2
		exit 1
		;;
esac

mkdir -p "$LOG_DIR"
sed "s|@CS16_LOG_DIR@|${LOG_DIR}|g" "$TEMPLATE" >"$DEST"
chmod 644 "$DEST"
echo "installed ${DEST} for log directory ${LOG_DIR}"
