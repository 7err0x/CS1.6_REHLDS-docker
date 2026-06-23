#!/usr/bin/env bash
# Fetches archives listed in MANIFEST → writes maps, sound, wads, models, sprites under OUT_DIR.
# Intended for Docker service `download-game-assets` or local OUT_DIR runs (see map-download-urls.manifest.txt).
set -euo pipefail

OUT_DIR="${OUT_DIR:-./data/cs16-game-assets}"
LIST="${MANIFEST:-${LIST:-}}"

goldsrc_bsp() {
	local f=$1
	[[ "$(head -c 4 "$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')" == "1e000000" ]]
}

sniff_ext() {
	local f=$1
	local m
	m="$(file -b --mime-type "$f" 2>/dev/null || true)"
	case "$m" in
		application/x-rar|application/vnd.rar|application/x-rar-compressed) echo rar ;;
		application/zip) echo zip ;;
		application/x-7z-compressed) echo 7z ;;
		*) echo "" ;;
	esac
}

validate_download_url() {
	local url=$1
	case "$url" in
		http://*|https://*) ;;
		*) echo "Rejected URL (http/https only): $url" >&2; return 1 ;;
	esac
}

reject_unsafe_extract_tree() {
	local root=$1
	local bad
	bad="$(find "$root" \( -path '*/../*' -o -path '*/../*/*' -o -name '..' \) -print -quit 2>/dev/null || true)"
	if [[ -n "$bad" ]]; then
		echo "Rejected archive path (zip-slip): $bad" >&2
		return 1
	fi
	while IFS= read -r -d '' link; do
		echo "Rejected symlink in archive: $link" >&2
		return 1
	done < <(find "$root" -type l -print0 2>/dev/null)
	return 0
}

extract_archive() {
	local filepath=$1
	local dest=$2
	local arch=$3
	mkdir -p "$dest"
	case "$arch" in
		rar) (cd "$dest" && unrar-free x -o+ "$filepath") ;;
		zip)
			local entry
			while IFS= read -r entry; do
				[[ -z "$entry" ]] && continue
				if [[ "$entry" == /* || "$entry" == ../* || "$entry" == */../* ]]; then
					echo "Rejected zip entry (zip-slip): $entry" >&2
					return 1
				fi
			done < <(unzip -Z1 "$filepath")
			unzip -q -o "$filepath" -d "$dest"
			;;
		7z)
			if command -v 7zr >/dev/null 2>&1; then
				7zr x -y -o"$dest" "$filepath"
			elif command -v 7z >/dev/null 2>&1; then
				7z x -y -o"$dest" "$filepath"
			else
				echo "7z archive but no 7zr/7z installed: $filepath" >&2
				return 1
			fi
			;;
		*) echo "Unknown archive type: $filepath" >&2; return 1 ;;
	esac
}

archive_type_from_path() {
	local p=${1,,}
	case "$p" in
		*.rar) echo rar ;;
		*.zip|*.pk3) echo zip ;;
		*.7z) echo 7z ;;
		*) echo "" ;;
	esac
}

# Walk parents of $f upward; print path suffix under the first ancestor dir named $want (case-insensitive basename).
rel_after_named_dir() {
	local f="$1" want="${2,,}"
	local p dir
	p="$(dirname "$f")"
	while [[ "$p" != "/" && "$p" != "." && -n "$p" ]]; do
		dir="$(basename "$p")"
		if [[ "${dir,,}" == "$want" ]]; then
			printf '%s\n' "${f#"$p"/}"
			return 0
		fi
		p="$(dirname "$p")"
	done
	return 1
}

install_extracted_assets() {
	local root=$1
	local bsp wad wav rel f mrel srel

	while IFS= read -r -d '' bsp; do
		if goldsrc_bsp "$bsp"; then
			install -D -m0644 "$bsp" "$OUT_DIR/maps/$(basename "$bsp")"
			echo "  map: $(basename "$bsp")"
		else
			echo "  skip non-GoldSrc bsp: $bsp" >&2
		fi
	done < <(find "$root" -type f -name '*.bsp' -print0 2>/dev/null)

	while IFS= read -r -d '' wad; do
		install -D -m0644 "$wad" "$OUT_DIR/wads/$(basename "$wad")"
		echo "  wad: $(basename "$wad")"
	done < <(find "$root" -type f \( -iname '*.wad' \) -print0 2>/dev/null)

	while IFS= read -r -d '' wav; do
		rel=""
		case "$wav" in
			*/sound/*) rel="${wav#*/sound/}" ;;
			*/Sound/*) rel="${wav#*/Sound/}" ;;
		esac
		if [[ -n "$rel" ]]; then
			install -D -m0644 "$wav" "$OUT_DIR/sound/$rel"
		else
			install -D -m0644 "$wav" "$OUT_DIR/sound/_flat/$(basename "$wav")"
		fi
		echo "  sound: ${rel:-_flat/$(basename "$wav")}"
	done < <(find "$root" -type f \( -iname '*.wav' -o -iname '*.mp3' \) -print0 2>/dev/null)

	while IFS= read -r -d '' f; do
		if mrel="$(rel_after_named_dir "$f" models)"; then
			install -D -m0644 "$f" "$OUT_DIR/models/$mrel"
			echo "  model: $mrel"
		elif srel="$(rel_after_named_dir "$f" sprites)"; then
			install -D -m0644 "$f" "$OUT_DIR/sprites/$srel"
			echo "  sprite: $srel"
		fi
	done < <(find "$root" -type f -print0 2>/dev/null)
}

fetch_one() {
	local dl=$1

	echo ">>> $dl"
	tmp="$(mktemp)"
	dest="$(mktemp -d)"
	validate_download_url "$dl" || return 1
	curl -fsSL -L --connect-timeout 30 --max-time 600 --max-redirs 5 -o "$tmp" "$dl"

	path_hint="$(archive_type_from_path "$dl")"
	sniffed="$(sniff_ext "$tmp")"
	arch="${path_hint:-$sniffed}"
	if [[ -z "$arch" ]]; then
		rm -rf "$dest" "$tmp"
		echo "Could not infer archive type (URL + file magic): $dl" >&2
		return 1
	fi

	if ! extract_archive "$tmp" "$dest" "$arch"; then
		rm -rf "$dest" "$tmp"
		return 1
	fi

	if ! reject_unsafe_extract_tree "$dest"; then
		rm -rf "$dest" "$tmp"
		return 1
	fi

	install_extracted_assets "$dest"
	rm -rf "$dest" "$tmp"
}

# WADs required by community BSPs but not always shipped inside map archives.
fetch_required_wads() {
	local entry name url dest

	for entry in \
		"de_vegas.wad|https://hl2go.com/downloads/cs1-6/maps/wad-files/de_vegas-wad/?download=8222"
	do
		name="${entry%%|*}"
		url="${entry#*|}"
		dest="$OUT_DIR/wads/$name"

		if [[ -f "$dest" ]]; then
			echo "  wad ok: $name"
			continue
		fi

		echo ">>> required wad: $name"
		if ! fetch_one "$url"; then
			echo "Failed to fetch required WAD: $name" >&2
			return 1
		fi
	done
}

main() {
	if [[ -z "${LIST:-}" ]]; then
		echo "MANIFEST env or LIST must point at a URL list file" >&2
		exit 1
	fi
	if [[ ! -f "$LIST" ]]; then
		echo "Manifest missing: $LIST" >&2
		exit 1
	fi

	mkdir -p "$OUT_DIR/maps" "$OUT_DIR/sound/_flat" "$OUT_DIR/wads" "$OUT_DIR/models" "$OUT_DIR/sprites"
	echo "Writing assets to $OUT_DIR"

	if ! fetch_required_wads; then
		exit 1
	fi

	local line failed=0
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
		if ! fetch_one "$line"; then
			failed=$((failed + 1))
		fi
	done < "$LIST"

	echo "Done. Failures: $failed"
	if [[ "$failed" -gt 0 ]]; then
		exit 1
	fi
}

main "$@"
