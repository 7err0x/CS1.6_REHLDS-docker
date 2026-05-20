#!/bin/sh
# GoldSrc clients request foo.bsp.bz2 when present; generate sidecars for large files.
set -eu

html="${1:-/usr/share/nginx/html}"
min_kb="${FASTDL_BZ2_MIN_KB:-256}"

find "$html" -type f ! -name '*.bz2' ! -name '*.bz2.tmp' \( \
	-name '*.bsp' -o -name '*.wad' -o -name '*.mdl' -o -name '*.spr' -o -name '*.tga' \
	-o -name '*.wav' -o -name '*.mp3' -o -name '*.txt' \
\) -size "+${min_kb}k" 2>/dev/null | while IFS= read -r f; do
	out="${f}.bz2"
	if [ ! -f "$out" ] || [ "$f" -nt "$out" ]; then
		echo "bzip2: $f"
		bzip2 -k -9 -f "$f"
	fi
done
