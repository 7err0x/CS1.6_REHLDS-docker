Community maps, sounds, WADs, models, and sprites for cs16 / cs16-biohazard / fastdl.

Populate from the repo root:

  mkdir -p data/cs16-game-assets
  docker compose --profile download-assets run --rm download-game-assets

Or copy files manually into maps/, sound/, wads/, models/, sprites/ (paths mirror cstrike/).

Required WAD: zm_toronto (and some fy_/aim maps) need de_vegas.wad — fetch_required_wads in
map-download.sh installs it into wads/ (merged to cstrike/de_vegas.wad at server start).

Edit image/game-assets/map-download-urls.manifest.txt and re-run download-game-assets to refresh.
