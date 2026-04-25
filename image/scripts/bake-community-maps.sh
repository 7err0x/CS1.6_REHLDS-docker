#!/usr/bin/env bash
# Downloads small community maps at image build time (requires network).
# BSP source: https://www.csboost.eu/ — geometry only.
# de_vegas.wad: many FY/aim maps reference this texture WAD; minimal HLDS trees often omit it.
set -euo pipefail

MAPS_DIR="${MAPS_DIR:-/opt/steam/hlds/cstrike/maps}"
CSTRIKE_DIR="${CSTRIKE_DIR:-$(dirname "$MAPS_DIR")}"
BASE_URL="${MAP_DOWNLOAD_BASE:-https://www.csboost.eu/downloads/maps}"
# WordPress attachment download URL (zip contains a single de_vegas.wad at cstrike root).
DE_VEGAS_WAD_ZIP_URL="${DE_VEGAS_WAD_ZIP_URL:-https://hl2go.com/downloads/cs1-6/maps/wad-files/de_vegas-wad/?download=8222}"

mkdir -p "$MAPS_DIR"

fetch_map() {
  local name="$1"
  echo "Fetching ${name}.bsp ..."
  curl -fsSL -o "${MAPS_DIR}/${name}.bsp" "${BASE_URL}/${name}.bsp"
}

fetch_de_vegas_wad() {
  local zip
  zip="$(mktemp)"
  echo "Fetching de_vegas.wad (texture WAD for several community maps) ..."
  curl -fsSL -o "$zip" "$DE_VEGAS_WAD_ZIP_URL"
  unzip -o -j "$zip" -d "$CSTRIKE_DIR"
  rm -f "$zip"
}

# Compact FY / aim / AWP arenas — strong defaults for respawn (ReGameDLL).
fetch_map fy_iceworld
fetch_map aim_map
fetch_map fy_snow
fetch_map awp_india

fetch_de_vegas_wad

echo "Community maps baked into ${MAPS_DIR}"
echo "Texture WAD de_vegas.wad installed into ${CSTRIKE_DIR}"
