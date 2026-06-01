Community map/mod payloads live in the Docker named volume **cs16-game-assets** (not a host bind mount).

Populate once:

  docker compose --profile download-assets run --rm download-game-assets

The game server and FastDL read from that volume at **/mnt/cs16-game-assets**. Edit URLs in
**image/game-assets/map-download-urls.manifest.txt**, then re-run the command above.

Optional: keep files under **./data/cs16-game-assets/** on the host for manual staging (gitignored);
copy into the volume with:

  docker compose --profile download-assets run --rm -v "$(pwd)/data/cs16-game-assets:/in:ro" \
    download-game-assets sh -c 'cp -a /in/. /out/'

Configs (**server.cfg**, **config/**, **users.ini**, **reunion.cfg**, Biohazard **plugins.ini**) are
baked into the image from **cstrike/** in the repo — change them there and **docker compose build**.
