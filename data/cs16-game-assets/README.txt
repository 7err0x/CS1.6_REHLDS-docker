Community maps, sounds, WADs, models, and sprites for cs16 / cs16-biohazard / fastdl.

Populate from the repo root:

  mkdir -p data/cs16-game-assets
  docker compose --profile download-assets run --rm download-game-assets

Or copy files manually into maps/, sound/, wads/, models/, sprites/ (paths mirror cstrike/).

Required WADs:
- de_vegas.wad — zm_toronto and some fy_/aim maps (fetch_required_wads in map-download.sh).
- react.wad — zm_dust2_2x2_fixed (inside that map's HL2GO archive; symlinked at cstrike/react.wad).

Both install into wads/ and are merged to cstrike/<name>.wad at server start (see extra-wad-symlinks.txt).

Edit image/game-assets/map-download-urls.manifest.txt and re-run download-game-assets to refresh.
