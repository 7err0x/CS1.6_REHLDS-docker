#!/usr/bin/env bash
# Resolve latest stable release tags for the rehlds GitHub stack (for CI build-args).
set -euo pipefail

latest_tag() {
	local repo=$1
	curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name'
}

REHLDS_BUILD=$(latest_tag rehlds/ReHLDS)
METAMOD_VERSION=$(latest_tag rehlds/Metamod-R)
REGAMEDLL_VERSION=$(latest_tag rehlds/ReGameDLL_CS)
REAPI_VERSION=$(latest_tag rehlds/ReAPI)
REUNION_VERSION=$(latest_tag rehlds/ReUnion)

for v in "$REHLDS_BUILD" "$METAMOD_VERSION" "$REGAMEDLL_VERSION" "$REAPI_VERSION" "$REUNION_VERSION"; do
	if [[ -z "$v" || "$v" == "null" ]]; then
		echo "error: failed to resolve a release tag" >&2
		exit 1
	fi
done

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
	{
		echo "rehlds=${REHLDS_BUILD}"
		echo "metamod=${METAMOD_VERSION}"
		echo "regamedll=${REGAMEDLL_VERSION}"
		echo "reapi=${REAPI_VERSION}"
		echo "reunion=${REUNION_VERSION}"
	} >>"$GITHUB_OUTPUT"
fi

echo "ReHLDS stack: ReHLDS=${REHLDS_BUILD} Metamod=${METAMOD_VERSION} ReGameDLL=${REGAMEDLL_VERSION} ReAPI=${REAPI_VERSION} ReUnion=${REUNION_VERSION}"
