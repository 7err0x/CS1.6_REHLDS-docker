Extras volume for **`cs16`** / **`cs16-biohazard`** / **`fastdl`**.

------------------------------------------------------------------------------
A) Automatic (URL list + Docker)
------------------------------------------------------------------------------

```bash
docker compose --profile download-assets run --rm download-game-assets
```

Edit **`image/game-assets/map-download-urls.manifest.txt`** in this repo (path from repo root), or mount your own list and set **`MANIFEST`** (see repository **README.md**).

------------------------------------------------------------------------------
B) Manual download from the web (browser → your PC → this folder)
------------------------------------------------------------------------------

1. Download the mod or map archive in a browser (ZIP / RAR / 7z). GameBanana,
   map archives, HL2GO, etc. work as long as you save the real archive file, not
   an HTML page.

2. Extract on your machine (file manager, unzip, unrar, 7-Zip).

3. Copy into this folder tree so paths mirror **`cstrike`** content (the server
   entrypoint merges them into **`/opt/steam/hlds/cstrike/`**):

   data/cs16-game-assets/
     maps/           ← GoldSrc **.bsp** files (basename must match **mapcycle**)
     sound/          ← subtree like **cstrike/sound/** (e.g. sound/weapons/foo.wav)
     wads/           ← **.wad** textures → copied to **cstrike/** root at startup
     models/         ← optional (**cstrike/models/**)
     sprites/        ← optional (**cstrike/sprites/**)

   Common cases:

   - **`cstrike/maps/foo.bsp`** → **`maps/foo.bsp`**
   - **`cstrike/sound/...`**     → **`sound/...`** (preserve folders under sound/)
   - Any **`.wad`**               → **`wads/`** (you may also drop **`.wad`** files
     in **`data/cs16-game-assets/`** root; merge copies those too.)

4. Restart containers that serve files:

     docker compose restart cs16-biohazard   # or cs16
     docker compose restart fastdl           # if you use profile fastdl

------------------------------------------------------------------------------
C) Upload archive from another machine onto the Docker host
------------------------------------------------------------------------------

Place files under **`.../cs16docker/data/cs16-game-assets/`** on the host:

  scp mypack.zip user@your-host:/path/to/cs16docker/data/cs16-game-assets/incoming/

Create **`incoming/`** yourself if you want a staging area — it is ignored by
the merge unless you later move BSP/sound/wad into **maps/**, **sound/**,
**wads/**.

Or sync already-extracted paths:

  rsync -av ./extracted/cstrike/maps/ user@host:/path/to/cs16docker/data/cs16-game-assets/maps/

**Docker cp** (drops file inside the container; ephemeral unless you also copy
to the bind mount):

  docker cp mymap.bsp cs16-biohazard0:/opt/steam/hlds/cstrike/maps/

For persistence, prefer the **`data/cs16-game-assets/`** bind mount.

------------------------------------------------------------------------------
D) Optional — unpack inside the downloader image (advanced)
------------------------------------------------------------------------------

Mount the archive read-only and a shell:

  docker compose --profile download-assets run --rm --entrypoint bash \
    -v /path/on/host:/in:ro -v "$(pwd)/data/cs16-game-assets:/out" download-game-assets

Inside the container: **`apt-get update && apt-get install -y unzip`** (or use
host **unrar** / **7z** on your PC instead), extract under **`/tmp`**, then
copy **.bsp** → **`/out/maps/`**, **sound** tree → **`/out/sound/`**, **.wad**
→ **`/out/wads/`**.

Usually extracting on the host with your desktop tools is easier.

------------------------------------------------------------------------------
Summary
------------------------------------------------------------------------------

**maps/**     — **.bsp**  
**sound/**    — **.wav** / **.mp3** mirroring game paths under **sound/**  
**wads/**     — **.wad** for **cstrike** root  
**models/**   — optional  
**sprites/**  — optional  

Keep this directory writable for your user before **`docker compose up`**.
