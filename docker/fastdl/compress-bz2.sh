#!/bin/sh
# GoldSrc FastDL: create file.ext.bz2 sidecars next to originals (client requests .bz2 when present).
set -e

root="${1:-/usr/share/nginx/html}"
min_bytes="${CS16_FASTDL_BZ2_MIN_BYTES:-4096}"

if [ ! -d "$root" ]; then
	exit 0
fi

echo "[fastdl] bzip2 sidecars under ${root} (min ${min_bytes} bytes)"

find "$root" -type f ! -name '*.bz2' \( \
	-iname '*.bsp' -o -iname '*.wad' -o -iname '*.mdl' -o \
	-iname '*.wav' -o -iname '*.spr' -o -iname '*.tga' \
\) -print 2>/dev/null | while IFS= read -r f; do
	[ -f "$f" ] || continue
	size=$(stat -c%s "$f" 2>/dev/null || echo 0)
	[ "$size" -ge "$min_bytes" ] || continue
	bz2="${f}.bz2"
	if [ ! -f "$bz2" ] || [ "$f" -nt "$bz2" ]; then
		bzip2 -k -f -9 "$f"
	fi
done
