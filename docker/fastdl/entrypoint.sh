#!/bin/sh
# Populate nginx docroot from /built (cs16-bootstrap + gfx/resource at image build),
# cs16-state volume (live server tree), then cs16-game-assets.
# Use cp -r only (not -a): read_only root + tmpfs html cannot preserve ownership.
set -e

# nginx master expects these; create before nginx starts (avoids chown on read-only layers).
cache=/var/cache/nginx
mkdir -p "$cache/client_temp" "$cache/proxy_temp" "$cache/fastcgi_temp" \
	"$cache/uwsgi_temp" "$cache/scgi_temp"
if id nginx >/dev/null 2>&1; then
	chown -R nginx:nginx "$cache" 2>/dev/null || chmod -R 777 "$cache"
else
	chmod -R 777 "$cache"
fi

html=/usr/share/nginx/html
mkdir -p "$html/maps" "$html/sound" "$html/models" "$html/sprites" "$html/gfx" "$html/resource" "$html/overviews"

if [ -d /built/maps ]; then cp -r /built/maps/. "$html/maps/"; fi
if [ -d /built/sound ]; then cp -r /built/sound/. "$html/sound/"; fi
if [ -d /built/models ]; then cp -r /built/models/. "$html/models/"; fi
if [ -d /built/sprites ]; then cp -r /built/sprites/. "$html/sprites/"; fi
if [ -d /built/gfx ]; then cp -r /built/gfx/. "$html/gfx/"; fi
if [ -d /built/resource ]; then cp -r /built/resource/. "$html/resource/"; fi
if [ -d /built/overviews ]; then cp -r /built/overviews/. "$html/overviews/"; fi
for w in /built/*.wad; do
	if [ -f "$w" ]; then cp "$w" "$html/"; fi
done

state=/var/cs16/state
if [ -d "$state/maps" ]; then cp -r "$state/maps/." "$html/maps/"; fi
if [ -d "$state/sound" ]; then cp -r "$state/sound/." "$html/sound/"; fi
if [ -d "$state/models" ]; then cp -r "$state/models/." "$html/models/"; fi
if [ -d "$state/sprites" ]; then cp -r "$state/sprites/." "$html/sprites/"; fi
if [ -d "$state/wads" ]; then
	for w in "$state/wads"/*.wad "$state/wads"/*.WAD; do
		if [ -f "$w" ]; then cp "$w" "$html/"; fi
	done
fi

if [ -d /mnt/cs16-game-assets/maps ]; then cp -r /mnt/cs16-game-assets/maps/. "$html/maps/"; fi
if [ -d /mnt/cs16-game-assets/sound ]; then mkdir -p "$html/sound" && cp -r /mnt/cs16-game-assets/sound/. "$html/sound/"; fi
if [ -d /mnt/cs16-game-assets/models ]; then mkdir -p "$html/models" && cp -r /mnt/cs16-game-assets/models/. "$html/models/"; fi
if [ -d /mnt/cs16-game-assets/sprites ]; then mkdir -p "$html/sprites" && cp -r /mnt/cs16-game-assets/sprites/. "$html/sprites/"; fi
if [ -d /mnt/cs16-game-assets/wads ]; then
	for w in /mnt/cs16-game-assets/wads/*.wad /mnt/cs16-game-assets/wads/*.WAD; do
		if [ -f "$w" ]; then cp "$w" "$html/"; fi
	done
fi
for w in /mnt/cs16-game-assets/*.wad /mnt/cs16-game-assets/*.WAD; do
	if [ -f "$w" ]; then cp "$w" "$html/"; fi
done

/usr/local/bin/compress-bz2.sh "$html"

exec nginx -g 'daemon off;'
