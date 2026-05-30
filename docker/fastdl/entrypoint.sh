#!/bin/sh
set -e
html=/usr/share/nginx/html
mkdir -p "$html/maps" "$html/sound" "$html/models" "$html/sprites" "$html/gfx" "$html/resource" "$html/overviews"

if [ -d /built/maps ]; then cp -a /built/maps/. "$html/maps/"; fi
if [ -d /built/sound ]; then cp -a /built/sound/. "$html/sound/"; fi
if [ -d /built/models ]; then cp -a /built/models/. "$html/models/"; fi
if [ -d /built/sprites ]; then cp -a /built/sprites/. "$html/sprites/"; fi
if [ -d /built/gfx ]; then cp -a /built/gfx/. "$html/gfx/"; fi
if [ -d /built/resource ]; then cp -a /built/resource/. "$html/resource/"; fi
if [ -d /built/overviews ]; then cp -a /built/overviews/. "$html/overviews/"; fi
for w in /built/*.wad; do
	if [ -f "$w" ]; then cp -a "$w" "$html/"; fi
done

if [ -d /mnt/cs16-game-assets/maps ]; then cp -af /mnt/cs16-game-assets/maps/. "$html/maps/"; fi
if [ -d /mnt/cs16-game-assets/sound ]; then mkdir -p "$html/sound" && cp -af /mnt/cs16-game-assets/sound/. "$html/sound/"; fi
if [ -d /mnt/cs16-game-assets/models ]; then mkdir -p "$html/models" && cp -af /mnt/cs16-game-assets/models/. "$html/models/"; fi
if [ -d /mnt/cs16-game-assets/sprites ]; then mkdir -p "$html/sprites" && cp -af /mnt/cs16-game-assets/sprites/. "$html/sprites/"; fi
if [ -d /mnt/cs16-game-assets/wads ]; then
	for w in /mnt/cs16-game-assets/wads/*.wad /mnt/cs16-game-assets/wads/*.WAD; do
		if [ -f "$w" ]; then cp -af "$w" "$html/"; fi
	done
fi
for w in /mnt/cs16-game-assets/*.wad /mnt/cs16-game-assets/*.WAD; do
	if [ -f "$w" ]; then cp -af "$w" "$html/"; fi
done

exec nginx -g 'daemon off;'
