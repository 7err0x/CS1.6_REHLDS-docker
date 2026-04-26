#!/usr/bin/env bash
# Downloads popular dark/night ZM maps from HL2GO (RAR) and installs BSPs into maps/.
# Requires: unrar-free, curl (Dockerfile runs this in stage `zm-maps` from debian:bookworm-slim).
# URLs: image/zombiemod/hl2go-zm-urls.txt (override with ZM_MAPS_URL_FILE).
set -euo pipefail

MAPS_DIR="${MAPS_DIR:-/opt/steam/hlds/cstrike/maps}"
LIST="${ZM_MAPS_URL_FILE:-/tmp/hl2go-zm-urls.txt}"

goldsrc_bsp() {
  local f=$1
  [[ "$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')" == "1e000000" ]]
}

fetch_hl2go_rar() {
  local url=$1
  local rar tmpd
  echo "Fetching ZM pack: $url"
  rar="$(mktemp)"
  curl -fsSL -L -o "$rar" "$url"
  tmpd="$(mktemp -d)"
  (cd "$tmpd" && unrar-free x "$rar" || { echo "unrar-free failed for $url" >&2; exit 1; })
  local found=0
  while IFS= read -r -d '' bsp; do
    if goldsrc_bsp "$bsp"; then
      cp -v "$bsp" "$MAPS_DIR/"
      found=1
    else
      echo "Skipping non-GoldSrc BSP: $bsp" >&2
    fi
  done < <(find "$tmpd" -type f -path '*/maps/*.bsp' -print0)
  rm -rf "$tmpd" "$rar"
  [[ "$found" -eq 1 ]] || { echo "No GoldSrc .bsp found under */maps/ for $url" >&2; exit 1; }
}

mkdir -p "$MAPS_DIR"

if [[ ! -f "$LIST" ]]; then
  echo "ZM URL list missing: $LIST" >&2
  exit 1
fi

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  fetch_hl2go_rar "$line"
done < "$LIST"

echo "ZM maps (HL2GO) baked into ${MAPS_DIR}"
