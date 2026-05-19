# Counter-Strike 1.6 in Docker (respawn / deathmatch mode)

This stack runs a **Counter-Strike 1.6** dedicated server using a **small custom image** built `FROM` the upstream [rehlds-cstrike](https://github.com/BLSAlin/rehlds-cstrike) container (default **`ghcr.io/blsalin/rehlds-cstrike:edge`** — see [GHCR package](https://github.com/BLSAlin/rehlds-cstrike/pkgs/container/rehlds-cstrike)). The **Dockerfile** overlays **AMX Mod X 1.9** (Linux base tarball from [AlliedModders releases](https://github.com/alliedmodders/amxmodx/releases)) because the upstream image’s **1.8.2** build **segfaults** after map load on this stack. It also installs **[ReUnion](https://github.com/rehlds/ReUnion)** and configures **Metamod-r** to load **ReUnion** then **AMXX** (`plugins.ini`). **ReGameDLL** stays active for **respawn** (`mp_forcerespawn` in `cstrike/config/server.cfg`). **`liblist.gam`** keeps **`secure "0"`** and **`cstrike/config/server.cfg`** sets **`secure 0`** so **VAC is off** for broad client compatibility (Steam + typical non‑Steam builds). The image bakes a **respawn-oriented stock mapcycle**. Extra BSPs/wads/sounds come from **`./data/cs16-game-assets/`** (fed by **`image/game-assets/map-download-urls.manifest.txt`** + **`download-game-assets`**, manual drops, or **`image/custom-maps/`**).

**Requirements:** Docker with Compose, **x86_64** host (or Docker Desktop with **linux/amd64** emulation). **Steam and non‑Steam** clients can join when ReUnion + `secure 0` are in effect (see **`reunion.cfg`** baked into the image).

---

## Quick start

1. Copy the environment file and set at least **`RCON_PASSWORD`**. Compose reads project **`.env`** for variable substitution (optional but recommended):

   ```bash
   cp .env.example .env
   ```

2. Build the game image (needs **network** once at build for **AMXX** / **ReUnion** / LaserMine tarballs and similar), then start:

   ```bash
   docker compose build --pull
   docker compose up -d
   ```

3. In CS 1.6, open the console (`~`) and connect (use **`SERVER_PORT`** from **`.env`**; the default publish mapping is **27016** on the host → **27015** in the container):

   ```text
   connect 127.0.0.1:27016
   ```

4. Watch logs:

   ```bash
   docker compose logs -f
   ```

---

## Configuration

| Item | Purpose |
|------|--------|
| `.env` | Port, slots, **RCON password**, start map, hostname (see `.env.example`). Optional **`AMXX_BASE_URL`** overrides the AMXX tarball used at **image build** time (Compose passes it as a build arg). |
| `cstrike/config/server.cfg` | Gameplay: **respawn**, teams vs FFA, round time, etc. Also **`secure 0`** / **`mp_consistency 0`** (VAC off; complements **`liblist.gam`**). |
| `cstrike/config/gamemode-biohazard.cfg` | **`cs16-biohazard`** boot **`+exec`**: **`mapcyclefile`** / flashlight. |
| `cstrike/config/server-biohazard.cfg` | Mounted as **`server.cfg`** on **`cs16-biohazard` only** — like **`server.cfg`** but **`mp_forcerespawn 0`** + **`mapcycle.biohazard.txt`**. |
| `cstrike/amxmodx/users.ini` | **AMXX** admins (Steam ID / IP / flags). Mounted into **`addons/amxmodx/configs/users.ini`**. |
| `reunion.cfg` (in image) | ReUnion auth: **`AuthVersion = 2`**, **`cid_NoSteam47/48 = 3`** (STEAM\_ IDs by IP) so non‑Steam clients are not rejected. Mount your own copy over `/opt/steam/hlds/cstrike/reunion.cfg` if you need stricter rules. |

After editing `.env` or `cstrike/config/server.cfg`:

```bash
docker compose up -d --force-recreate
```

**Hostname** is applied from `.env` via the process command line; gameplay cvars live in `cstrike/config/server.cfg`.

### Respawn and teams

In `cstrike/config/server.cfg`:

- **`mp_forcerespawn 1`** — turns on ReGameDLL **respawn / deathmatch-style** behaviour.
- **`mp_freeforall 0`** — keep **CT vs T**. Set to **`1`** for **everyone vs everyone**.

More ReGameDLL variables are documented in the [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS) project (see `dist/game.cfg` in that repo for defaults and comments).

### Maps, downloadable extras (`./data/cs16-game-assets/`), FastDL

| Path | Role |
|------|------|
| [`Dockerfile`](Dockerfile) | **`mapcycle*.txt`**, **`image/custom-maps/`** overlay (optional BSPs baked into **`cstrike/maps/`**), downloads **AMXX 1.9**, installs **`biohazard.amxx`** and **`plugins-*.ini`**, merges **`image/zombiemod/extra-assets/`**, **[ReUnion](https://github.com/rehlds/ReUnion)**, **`secure "0"`** in **`liblist.gam`**, patches **`reunion.cfg`**. **`zm_*` / WAD-heavy packs**: use **`download-game-assets`** → **`./data/cs16-game-assets/`** (see below). |
| [`image/mapcycle.txt`](image/mapcycle.txt) | **Stock** **`de_*`** / **`cs_*`** rotation for **respawn**. Add arenas or **`fy_*`** by syncing **`maps/`** (manifest + **`download-game-assets`**) or dropping BSPs under **`image/custom-maps/`** / **`data/cs16-game-assets/maps/`**. |
| [`image/custom-maps/`](image/custom-maps/) | Optional: add your own **`*.bsp`** here before `docker compose build`; they are **copied last** and can replace files with the same name. |
| [`docker-compose.yml`](docker-compose.yml) **`download-game-assets`** (profile **`download-assets`**) | One-shot image that runs **`image/scripts/map-download.sh`** → writes **`maps/`**, **`sound/`**, **`wads/`**, **`models/`**, **`sprites/`** under **`./data/cs16-game-assets/`** from URLs in **`image/game-assets/map-download-urls.manifest.txt`**. **`cs16`** / **`cs16-biohazard`** / **`fastdl`** bind-mount this tree (same host folder for server + FastDL). |
| [`image/game-assets/map-download-urls.manifest.txt`](image/game-assets/map-download-urls.manifest.txt) | **URL manifest**: one **direct** download per line (comments `#`). Default list is **HL2GO `zm_*` RARs** plus other URLs you add — mods on [GameBanana](https://gamebanana.com) must be pasted as resolved **CDN file URLs**, not browse pages (no scraping in the script). |
| [`image/scripts/map-download.sh`](image/scripts/map-download.sh) | Fetches manifests: **`.rar` / `.zip`** via **`curl -L`**, expands with **`unrar-free`/`unzip`**, keeps GoldSrc **`.bsp`**, nests **`wav`/`mp3`** under **`sound/`**, stores **`.wad`** in **`wads/`**, copies any extracted **`models/**`** and **`sprites/**`** trees into the same **`OUT_DIR`** (same layout as **`cstrike/`**). Merged into **`cstrike/`** at HLDS startup via **`cs16-merge-game-assets`**. **`MANIFEST`** / **`OUT_DIR`** env overrides supported. |
| [`data/cs16-game-assets/README.txt`](data/cs16-game-assets/README.txt) | Notes on the shared **`./data/cs16-game-assets/`** volume (permissions / layout). |
| [`image/mapcycle.biohazard.txt`](image/mapcycle.biohazard.txt) | **Biohazard** rotation: **`zm_*`** BSPs from **`./data/cs16-game-assets/maps/`**, then **`cs_*` / `de_*`** (stock). **`BIOHAZARD_START_MAP`** defaults to **`cs_estate`** (stock) so you can boot before syncing extras. |
| [`cstrike/config/gamemode-biohazard.cfg`](cstrike/config/gamemode-biohazard.cfg) | Boot **`+exec`**: **`mapcyclefile`** and **`mp_flashlight`**. |
| [`cstrike/config/server-biohazard.cfg`](cstrike/config/server-biohazard.cfg) | Mounted **as** **`config/server.cfg`** on **`cs16-biohazard`** — **`mp_forcerespawn 0`**, **`mapcycle.biohazard.txt`**, same VAC / comfort intent as the main **`server.cfg`**. |
| [`cstrike/config/fastdl.cfg`](cstrike/config/fastdl.cfg) | Optional **HTTP FastDL**: uncomment **`sv_downloadurl`** so clients download maps / models / sounds over **HTTP** instead of the slow in-game channel (see **FastDL** below). |
| [`docker-compose.yml`](docker-compose.yml) **`fastdl`** (profile **`fastdl`**) | **Nginx**: at **startup** merges **`maps/`/`sound/`/`models/`/… copied from **`CS16_IMAGE_NAME`** during **image build**, then overlays **`./data/cs16-game-assets`** (mounted read-only). Rebuild **`fastdl`** after game image bumps; **`restart`** is enough after extra downloads landed on disk. See **[`docker/fastdl/Dockerfile`](docker/fastdl/Dockerfile)**. |
| [`docker/fastdl/Dockerfile`](docker/fastdl/Dockerfile) | **`nginx:alpine`** + BuildKit **`RUN --mount`** snapshot of **`GAME_IMAGE`** `cstrike/`, plus **`entrypoint.sh`** merging **`/mnt/cs16-game-assets`** at start (same host extras as **`cs16`** / **`cs16-biohazard`**). |
| [`docker/fastdl/default.conf`](docker/fastdl/default.conf) | Nginx: static files, **`gzip off`**, **`application/octet-stream`**. |
| [`image/zombiemod/plugins-biohazard.ini`](image/zombiemod/plugins-biohazard.ini) | AMXX list for infection: stock admin stack, **`biohazard.amxx`**, **`lasermine.amxx`**, **`zp50_grenade_frost.amxx`** / **`zp50_grenade_fire.amxx`** (Bio ports of ZP grenades); **`nextmap`** / **`mapchooser`** commented. |

**Download extras (`download-assets` profile):**

```bash
mkdir -p data/cs16-game-assets
docker compose --profile download-assets run --rm download-game-assets
```

**Custom URL list:**

```bash
docker compose --profile download-assets run --rm \
  -e MANIFEST=/mnt/myurls.txt \
  -v "$PWD/my-gamebanana-urls.txt:/mnt/myurls.txt:ro" \
  download-game-assets
```

Outputs: **`./data/cs16-game-assets/{maps,sound,wads,models,sprites}/`** — mounted read-only into **`cs16`**, **`cs16-biohazard`**, and **`fastdl`**. Paste **direct file URLs** from mod hosts (including [GameBanana](https://gamebanana.com) file CDN links).

**Manual install — browser download or SCP:** unpack archives on your PC (or on the Docker host), then drop **`.bsp`** into **`data/cs16-game-assets/maps/`**, **`sound/**`**, **`wads/*.wad`**, etc. Full step-by-step layouts, **`docker cp`**, and optional image-based unpacking: **[`data/cs16-game-assets/README.txt`](data/cs16-game-assets/README.txt)**.

### Lasermines (Biohazard humans)

The image includes **[Amxx Laser TripMine Entity](https://github.com/AoiKagase/Amxx-Laser-TripMine-Entity)** compiled with **Biohazard** support. Defaults (see **`addons/amxmodx/configs/plugins/lasermine/bh_ltm_cvars.cfg`** in the baked pack):

- **2 mines** at the start of each round (`bh_ltm_amount`), up to **6** carried (`bh_ltm_max_amount`); buy more while inside the **buy zone** with enough **cash**.
- **Buy** (survivors / humans only on this server): console **`buy_lasermine`**, or chat **`/lm`**, **`/buy lasermine`**, or **`say /lasermine`** (opens help). Price and buy-zone rules: **`bh_ltm_buy_price`**, **`bh_ltm_buy_zone`**, **`bh_ltm_buy_mode`** in the same file.
- **Place**: bind a key to **`+setlaser`** or **`+setlm`** (release to finish).
- **Pick up / remove your mine**: aim within ~128 units and hold **USE** (default **E**), or bind **`+dellaser`** / **`-dellaser`** (same hold/release pattern as **`+setlaser`** — use **`bind KEY +dellaser`**, not `bind KEY dellaser`). Upstream sources only hooked USE; this image also registers **`+dellaser`** so the in-plugin help matches behavior.
- A **scrolling chat reminder** is set in **`cstrike/config/server-biohazard.cfg`** (`amx_scrollmsg`). In-game **`say lasermine`** uses **`addons/amxmodx/data/lang/lasermine.txt`** (`REFER` line).

### Zombie night vision

Classic Biohazard set a **private HUD “has NVG” bit** (`pdata`/offset hacks). Current **HLDS/ReGameDLL** only honors night vision when **`m_bHasNightVision`** is set on the CS player (`ClientCommand nightvision` **returns immediately** otherwise), so goggles never toggle reliably. This repo **`fm_set_user_nvg`** delegates to **`cs_set_user_nvg`** from **`#include <cstrike>`** so infection/cure stays in sync with the game DLL; **alive zombies** additionally have **`nightvision`** handled in **`biohazard.sma`**, sending **`NVGToggle`** (**`get_user_msgid("NVGToggle")`**) plus **`items/nvg_on.wav` / `nvg_off.wav`**, bypassing flaky native command handling. Earlier tweaks remain: **`FM_CmdStart`** no longer strips impulse **100**, **`fwd_emitsound`** no longer supersede **`items/nvg_*.wav`**, and **`customflashlight`** leaves impulse **100** alone for zombies. Bind **`nightvision`** (often default **N**). **`bh_autonvg`** runs **`nightvision`** once after infect if enabled.

### Map brightness and flashlights (Biohazard)

**`cs16-biohazard` only** — the respawn **`cs16`** profile does not load Biohazard lighting overrides.

#### Whole-map brightness (server)

GoldSrc uses a single **ambient light style** for the map. Biohazard sets it from **`bh_lights`** in **`image/zombiemod/extra-assets/addons/amxmodx/configs/bh_cvars.cfg`** (baked into the image; reapplied every few seconds via **`biohazard.sma`**):

| Value | Effect |
|--------|--------|
| **`a`** … **`z`** | Darkest → brightest global ambient (`a` = very dark, `m`–`n` = typical indoor, `z` = very bright) |
| **`""`** (empty) | Disable override — use each map’s compiled lighting |

Related cvars in the same file:

- **`bh_skyname`** — sets **`sv_skyname`** (default **`drkg`** for a darker sky). Leave blank to stop overriding.
- When **`bh_lights`** is non-empty, Biohazard also forces **`sv_skycolor_r/g/b`** to **0** for a darker horizon.

**Night `zm_*` maps** are often dark in the BSP; raising **`bh_lights`** (e.g. **`m`** or **`p`**) is the usual fix. Per-room lighting baked into a **`.bsp`** cannot be changed from config without recompiling the map.

**Runtime (after join, with RCON):**

```text
rcon bh_lights m
rcon bh_skyname ""
```

Rebuild the image only if you edit **`bh_cvars.cfg`** on the host before **`docker compose build`**; RCON changes apply until restart.

**Per-player “brightness”** (video **gamma** / **brightness** in the CS client menu) is **client-only** and does not affect other players.

#### Flashlights

Two layers on Biohazard:

1. **Engine flashlight** — **`mp_flashlight 1`** in **`cstrike/config/gamemode-biohazard.cfg`** and **`cstrike/config/server-biohazard.cfg`**. Players use the default bind (**impulse 100**, often **F**). This is the stock HL cone; it does not brighten the whole map.

2. **Custom flashlight plugin** — cvars at the bottom of **`bh_cvars.cfg`** ( **`customflashlight.sma`** in the Biohazard pack):

| Cvar | Role (defaults in repo) |
|------|-------------------------|
| **`flashlight_custom`** | **`1`** = custom drain/charge/colored beam; **`0`** = stock behavior only |
| **`flashlight_show_all`** | **`1`** = others see your beam; **`0`** = local only |
| **`flashlight_fulldrain_time`** | Seconds until battery empty (**`200`**) |
| **`flashlight_fullcharge_time`** | Seconds to recharge (**`15`**) |
| **`flashlight_color_type`** | **`0`** random palette, **`1`** team colors |
| **`flashlight_color_ct`** / **`flashlight_color_te`** | RGB string when type is **`1`** (e.g. **`255255255`**) |
| **`flashlight_radius`** | Survivor beam size (**`18`** in **`bh_cvars.cfg`**) — see **RCON** below |
| **`flashlight_distance_max`** | How far others see the beam (**`4000.0`**) |
| **`flashlight_attenuation`** | Falloff with distance (**`5`**) |

**Plugin must be loaded:** **`customflashlight.amxx`** ships under **`image/zombiemod/extra-assets/addons/amxmodx/plugins/`** but is **not** enabled in **`image/zombiemod/plugins-biohazard.ini`** by default. Add a line **`customflashlight.amxx`** (after **`biohazard.amxx`**) and restart **`cs16-biohazard`** so **`flashlight_*`** cvars do anything. With **`flashlight_custom 0`**, only stock **`mp_flashlight`** applies and **`flashlight_radius`** is ignored.

**Survivors only — zombies are excluded:** In **`customflashlight.sma`**, impulse **100** (default **F**) is ignored when **`is_user_zombie(id)`**; infection calls **`FlashlightTurnOff`**. The colored **`TE_DLIGHT`** beam (where **`flashlight_radius`** is read) runs only for **humans**. **Zombies** use **night vision** (**`nightvision`** / **`NVGToggle`** / **`bh_autonvg`** in **`biohazard.sma`**), which does **not** use **`flashlight_radius`**. To brighten zombies, use **`bh_lights`** (whole map) or NVG, not **`flashlight_radius`**.

**Set beam size from RCON (humans, custom plugin on):**

```text
rcon_password YOUR_RCON_PASSWORD
rcon flashlight_radius 25
```

Server console / **`docker exec`** (no **`rcon`** prefix): **`flashlight_radius 25`**.

Requirements: **`flashlight_custom 1`**, **`customflashlight.amxx`** loaded. The plugin reads **`flashlight_radius`** each time it draws the beam; toggle the flashlight off/on if you do not see a change. Other **`flashlight_*`** cvars use the same pattern (e.g. **`rcon flashlight_distance_max 3000`**).

**Persistence:** RCON changes last until the server restarts or the map changes — Biohazard **`exec`s `bh_cvars.cfg`** on each map load from **`plugin_precache()`**, which resets **`flashlight_radius`** to the value in that file. For a permanent default, edit **`bh_cvars.cfg`** and rebuild or copy into the container. **`bh_flashbang`** controls whether flashbangs only blind zombies.

### Survivor ammo (`bh_ammo`)

**`addons/amxmodx/configs/bh_cvars.cfg`** sets **`bh_ammo`** for **humans only** — Biohazard skips this logic while **`g_zombie`** is true. **`1`** tops up reserve when it hits empty; **`2`** keeps the current magazine topped up whenever **`CurWeapon`** updates and refills reserve, which behaves like infinite ammo during combat. Change **`biohazard.sma`** (**`bh_ammo`** handler in **`event_curweapon`**) and rebuild **`biohazard.amxx`** (Biohazard **§2**) if you need further tweaks beyond the **`bh_cvars.cfg`** knobs.

### Frost / napalm grenades (zp50-derived, Biohazard ports)

Bio profile enables **`zp50_grenade_frost.amxx`** and **`zp50_grenade_fire.amxx`** (after **`lasermine.amxx`** in **`plugins-biohazard.ini`**):

- **`zp50_grenade_frost.sma`**: survivors’ **flashbang** gets a blue **`kRenderFxGlowShell`** plus **`sprites/laserbeam.spr`** trail; on explosion it freezes nearby **zombies** for **`zp_grenade_frost_duration`** seconds (**`zp_grenade_frost_hudicon`** toggles Damage icon). Uses **`warcraft3/frostnova.wav`** (and siblings) — include those paths on FastDL if clients error on missing downloads.
- **`zp50_grenade_fire.sma`**: survivors’ **HE** gets red trail/orange cylinders; zombies in radius burn on **`zp_grenade_fire_duration`**-style stacking (**ticks** **`×5`** per 0.2s pulse, **`zp_grenade_fire_damage`**, slowdown **`zp_grenade_fire_slowdown`**). Burning uses **`#include fun`** (**`user_kill`**) — keep **`modules.ini`** **`fun`** enabled.

Verbatim zp50 originals (need **`zp50_core`**, **`amx_settings_api`**, etc.) live in **`addons/amxmodx/scripting/upstream/evandrocoan_MultiModServer/`**.

**Blue light without freeze:** optional **`bio_smokeflare`** — uncomment **`bio_smokeflare.amxx`** in **`plugins-biohazard.ini`** if wanted.

### FastDL (faster first-join downloads)

Without **FastDL**, GoldSrc clients pull custom files from the server over the **game connection**, which is slow for **`zm_*` BSPs**, large **`.wad`** files merged from **`data/cs16-game-assets/`**, and big mod packs (e.g. Biohazard **models/** / **sound/**).

**Option A — FastDL image in this repo (Compose profile `fastdl`):**

1. Build **game**, then **FastDL** (**`docker compose build cs16 fastdl`**). Changing **`GAME_IMAGE`** content or **`docker/fastdl/entrypoint.sh`** requires **`build fastdl`**. Adding files only under **`./data/cs16-game-assets/`** → **`restart`** (**`docker compose restart fastdl`**) usually enough — the nginx entrypoint overlays that mount each start.
2. Start FastDL: **`docker compose --profile fastdl up -d`** ( **`FASTDL_HTTP_PORT`**, default **8080** ).
3. In **`cstrike/config/fastdl.cfg`**, uncomment **`sv_downloadurl`** with a **trailing slash** (LAN example: **`http://192.168.1.10:8080/`**).
4. Restart game containers if you only changed **`fastdl.cfg`**: **`docker compose restart cs16`** (and **`cs16-biohazard`** if used).

**Option B — any other static host (CDN, VPS nginx, S3, …):** same path layout under the URL; set **`sv_downloadurl`** accordingly.

**Reload config only:** edit **`fastdl.cfg`** then **`docker compose restart cs16`** (and **`cs16-biohazard`** if applicable); no image rebuild.

**Optional speed-ups:** pre-compress large files as **`.bz2`** next to the originals (e.g. **`maps/foo.bsp.bz2`**); many clients will prefer the smaller download. Keep **`sv_allowdownload 1`** (already in **`fastdl.cfg`**) so the slow path still works as a fallback.

**Rebuild** after changing **`image/mapcycle*.txt`**, **`Dockerfile`**, or files under **`image/custom-maps/`**. **`image/game-assets/`** URL changes only require re-running **`download-assets`** (no image rebuild unless you change how **`download-game-assets`** is built):

```bash
docker compose build --no-cache
docker compose up -d --force-recreate
```

If a download URL breaks, edit **`image/game-assets/map-download-urls.manifest.txt`**, use **`MANIFEST=…`** override, paste BSPs/WADs into **`./data/cs16-game-assets/`**, or bake BSPs via **`image/custom-maps/`**.

---

## Biohazard / old-school infection (optional profile)

This profile listens on **`BIOHAZARD_SERVER_PORT`** (default **27017**). **`zm_*`** maps live in **`./data/cs16-game-assets/maps/`** — populate with **`compose --profile download-assets`**; **`BIOHAZARD_START_MAP`** defaults to **`cs_estate`** (stock) so you can boot before syncing HL2GO / GameBanana packs. **`biohazard.amxx`** stays baked from **`image/zombiemod/extra-plugins/`** — expand **`extra-assets/`** for vendor models/sounds.

The profile merges **`plugins-biohazard.ini`**, **`server-biohazard.cfg`**, and uses **`docker-compose.yml`** **`entrypoint`** (**`cs16-merge-game-assets-entrypoint.sh`**) ahead of **`hlds_run`** so **`./data/cs16-game-assets`** is layered into **`cstrike/`** each boot.

### 1. Biohazard AMXX plugin (included)

The image **bakes a compiled `biohazard.amxx`** from **`image/zombiemod/extra-plugins/`** (patched in-tree **`biohazard.sma`** under **`image/zombiemod/extra-assets/.../scripting/`** for NVG / compatibility; see **§2 below** to rebuild after editing the source). For the **full Biohazard public pack** (models, sounds, **zombie classes**, etc.), obtain **Biohazard v2.00 Beta 3b** from the official thread and merge assets into **`image/zombiemod/extra-assets/`** (see **`image/zombiemod/extra-assets/README.txt`**).

- [Biohazard v2.00 Beta 3b (Zombie Mod) — AlliedModders](https://forums.alliedmods.net/showthread.php?t=68523)

**Quick path for Docker (assets only if you do not have the pack yet):**

1. Extract the pack on your PC and merge **`models/`**, **`sound/`**, **`sprites/`**, extra **`addons/amxmodx/`** files you need into **`image/zombiemod/extra-assets/`** so its top-level folders match **`cstrike/`**.
2. Rebuild: **`docker compose build`** and **`docker compose --profile biohazard up -d --force-recreate`**.

**Replacing the main plugin:** drop your own **`biohazard.amxx`** into **`image/zombiemod/extra-plugins/`** if you use an unmodified vendor binary (you would lose the in-repo NVG tweak unless you apply the same patch).

### 2. Compiling `biohazard.sma` locally

The canonical sources in this repo are **`image/zombiemod/extra-assets/addons/amxmodx/scripting/biohazard.sma`** and **`…/scripting/biohazard.cfg`** (included via **`#tryinclude "biohazard.cfg"`** — the **`.cfg`** must sit next to the **`.sma`** when you compile). Use **AMX Mod X 1.9.x** to match the server image (see **`AMXX_BASE_URL` / `AMXX_CSTRIKE_URL`** in **`.env.example`** and the Dockerfile — same Counter-Strike add-on tarball the runtime needs for **`cstrike` / `csx` includes).

**On Linux (recommended layout):**

1. Download and extract **both** tarballs into one tree (paths match the official packages):
   - **Base:** [amxmodx-1.9.0-git5303-base-linux.tar.gz](https://github.com/alliedmodders/amxmodx/releases/download/1.9.0.5303/amxmodx-1.9.0-git5303-base-linux.tar.gz) (contains **`addons/amxmodx/scripting/amxxpc`** and includes).
   - **CS add-on:** [amxmodx-1.9.0-git5303-cstrike-linux.tar.gz](https://github.com/alliedmodders/amxmodx/releases/download/1.9.0.5303/amxmodx-1.9.0-git5303-cstrike-linux.tar.gz) (merge into the same **`cstrike/`** root so **`addons/amxmodx/modules/`** and includes are complete).

2. **`amxxpc`** is a **32-bit** binary. On **64-bit Debian/Ubuntu** install multilib support, for example: **`sudo dpkg --add-architecture i386`**, then **`sudo apt-get install libc6-i386 zlib1g:i386 libstdc++6:i386`** (same idea as the **`lasermine-biohazard-compile`** stage in the Dockerfile).

3. Copy **`biohazard.sma`** and **`biohazard.cfg`** into **`addons/amxmodx/scripting/`**. Copy **`image/zombiemod/extra-assets/addons/amxmodx/data/lang/biohazard.txt`** to **`addons/amxmodx/data/lang/biohazard.txt`** so the compiler can resolve the language file if needed.

4. From **`addons/amxmodx/scripting/`**:

   ```bash
   chmod +x amxxpc
   ./amxxpc biohazard.sma
   ```

5. The output is **`biohazard.amxx`** in that directory. Copy it to **`image/zombiemod/extra-plugins/biohazard.amxx`**, then rebuild the game image (**`docker compose build`**) so the new binary is baked into **`addons/amxmodx/plugins/`**.

**On Windows:** use the **Windows** AMXX base package from the same release, open **`compile.exe`** or run **`amxxpc.exe`** from the scripting folder with **`biohazard.sma`** and the same **`biohazard.cfg`** / **`data/lang/biohazard.txt`** layout under your local AMXX tree.

### 3. Start the Biohazard server

```bash
mkdir -p data/cs16-game-assets
docker compose --profile download-assets run --rm download-game-assets
docker compose build --pull
docker compose --profile biohazard up -d
```

- **Default listen:** **`BIOHAZARD_SERVER_PORT`** (**27017** → container **27015**). Connect from CS, for example: **`connect 127.0.0.1:27017`**.
- **Start map:** **`BIOHAZARD_START_MAP`** (default **`cs_estate`** — dark indoor stock map).
- **Hostname / RCON:** **`BIOHAZARD_SERVER_HOSTNAME`**, **`BIOHAZARD_RCON_PASSWORD`** (see **`.env.example`**).

The profile mounts **`plugins-biohazard.ini`**, **`server-biohazard.cfg`**, and uses **`docker-compose`** so **`command`** retains **`./hlds_run … +map`** (no baked **`+map de_dust2`** override).

### 4. Other zombie / ReAPI stacks (not in this image)

For a **ReAPI-native** rewrite (different install), see [ReBiohazard](https://github.com/nikolaygaus/ReBiohazard) — it targets **ReHLDS + ReGameDLL + ReAPI** and is **not** the same drop-in as classic Biohazard.

---

## Managing the server (Docker)

| Action | Command |
|--------|--------|
| Start (background) | `docker compose up -d` |
| Start **Biohazard** profile too | `docker compose --profile biohazard up -d` |
| Build FastDL from current game image | `docker compose build cs16 fastdl` |
| Start **FastDL** (HTTP; maps/mods from game image) | `docker compose --profile fastdl up -d` |
| Fetch **`zm_*` / GameBanana** archives → **`./data/cs16-game-assets/`** | `docker compose --profile download-assets run --rm download-game-assets` |
| Stop | `docker compose down` |
| Restart | `docker compose restart` |
| Logs (follow) | `docker compose logs -f` |
| Logs — Biohazard container | `docker compose logs -f cs16-biohazard` |
| Status | `docker compose ps` |

The container is named **`cs16-respawn0`** (`container_name` in Compose). One-off shell as the steam user (for debugging):

```bash
docker exec -it cs16-respawn0 bash
```

Game files live under `/opt/steam/hlds/cstrike` inside the container.

---

## RCON (remote console)

### GoldSrc vs Source (important)

**Counter-Strike 1.6** uses the **GoldSrc / HLDS** remote console: **UDP** to the **same port players use** (inside the container that is **27015**; on the host it is **`SERVER_PORT`** from **`.env`**, default **27016** in **`docker-compose.yml`**).

That is **not** the **Source engine RCON** protocol (**TCP**, different packet layout). Docker images built around **Source RCON** will **not** talk to this server. In particular, **[`outdead/rcon`](https://hub.docker.com/r/outdead/rcon)** ([gorcon/rcon-cli](https://github.com/gorcon/rcon-cli)) targets **Source / Web / Telnet** RCON for games like **CS:GO** — **do not use it for CS 1.6**.

### From the CS 1.6 game client (simplest)

1. Set **`RCON_PASSWORD`** in **`.env`** and **`docker compose up -d --force-recreate`** so the server uses it (Compose passes **`+rcon_password`** on startup).
2. Join the server from CS 1.6.
3. Open the console (**`~`**) and run:

   ```text
   rcon_password YOUR_PASSWORD_HERE
   rcon status
   rcon changelevel de_dust2
   ```

   Every **`rcon …`** line sends the text after **`rcon`** to the server console. Use the **same password** as **`RCON_PASSWORD`**.

4. **Address:** the client already knows the server; you do not type host/port in **`rcon`** lines. From another machine, you must **connect to that server first**, then use **`rcon`**.

### From the host without the game (UDP GoldSrc RCON)

There is **no single “official” Docker image** maintained here for GoldSrc RCON. Practical options:

- **Windows:** **[HLSW](https://www.hlsw.net/)** (Half-Life Server Watch) — classic GUI that speaks GoldSrc RCON; point it at **`YOUR_IP:SERVER_PORT`** and your RCON password.
- **Script / library:** community tools implement the **GoldSrc challenge–response** over UDP (e.g. Java [GoldSrcRcon](https://github.com/ahm3tcelik/GoldSrcRcon), PHP [Steam Condenser](https://github.com/koraktor/steam-condenser) GoldSrc support). You can wrap one in your own small **`Dockerfile`** if you want a containerized admin CLI.

If you only need **file edits** (maps, cvars in **`server.cfg`**, AMXX **`users.ini`**), **`docker compose logs -f`**, **`docker exec -it cs16-respawn0 bash`**, and **in-game `rcon`** cover most workflows without a separate RCON container.

### Useful server commands (via `rcon …` or server console)

| Command / variable | Effect |
|--------------------|--------|
| `changelevel de_dust2` | Load a map |
| `map de_dust2` | Load map (resets session) |
| `status` | List players |
| `kick #userid` | Kick by slot from `status` |
| `mp_forcerespawn 0` | Disable respawn (round CS again) |
| `mp_forcerespawn 1` | Enable respawn (ReGameDLL deathmatch-style) |
| `mp_freeforall 0` | Teams on (**CT vs T**) while respawn can stay on |
| `mp_freeforall 1` | Free-for-all (everyone vs everyone); pair with **`mp_forcerespawn 1`** for FFA DM |
| `mp_timelimit 45` | Map time limit (minutes) |
| `sv_restart 1` | Quick restart |
| `rcon_password ...` | Change RCON password at runtime (also set in `.env` for next restart) |
| `amx_reloadadmins` | Reload **`users.ini`** after you edit AMXX admins on the host |

### Respawn and deathmatch (RCON)

**ReGameDLL** uses **`mp_forcerespawn`** so players **respawn** instead of spectating until round end. Defaults are in **`cstrike/config/server.cfg`**; from the client console (after **`rcon_password`**):

| Goal | `rcon` examples |
|------|-----------------|
| **Respawn DM, teams (CT vs T)** | `rcon mp_forcerespawn 1` · `rcon mp_freeforall 0` |
| **FFA respawn deathmatch** | `rcon mp_forcerespawn 1` · `rcon mp_freeforall 1` |
| **Normal round-based CS** | `rcon mp_forcerespawn 0` · `rcon mp_freeforall 0` |

Use **`rcon mp_timelimit 30`** (or any **> 0** value) so the map does not run forever and **map voting** (below) can line up with map time.

### Map voting (stock AMXX)

Two stock plugins handle votes; both are in the default **`plugins.ini`**.

1. **End-of-map vote** — **`mapchooser.amxx`**: starts automatically when **`mp_timelimit` > 0** and map time left falls into AMXX’s **short end window** (on the order of the **last ~2 minutes**). Candidate maps come from **`addons/amxmodx/configs/maps.ini`** if that file exists, otherwise from **`mapcyclefile`** (this project bakes **`mapcycle.txt`**).

2. **Vote on demand** — **`adminvote.amxx`**: console command **`amx_votemap`** (up to **four** map names). Requires an admin with the **`j`** (**ADMIN_VOTE**) flag in **`users.ini`** (a long **`abcdefghijklmnopqrstu`** access string includes it). Examples:

   ```text
   rcon amx_votemap de_dust2 de_inferno cs_office
   rcon amx_votemap de_nuke de_train cs_italy
   rcon amx_cancelvote
   ```

If **`amx_votemap`** says you have no access, add **`j`** to your flags (or use a full admin string), save **`cstrike/amxmodx/users.ini`**, then **`rcon amx_reloadadmins`**.

---

## Using AMX Mod X (AMXX)

AMXX extends the server with plugins (menus, admin commands, map voting, etc.). This image ships the **1.9** stock **`plugins.ini`** (admin base, menus, mapchooser, antiflood, …).

### 1. Make yourself an admin

1. Open **`cstrike/amxmodx/users.ini`** on the host (it is bind-mounted; see [Adding Admins](https://wiki.alliedmods.net/Adding_Admins_(AMX_Mod_X))).
2. Add a line for your **SteamID**, **name**, or **IP**. Example (SteamID, full admin flags typical for 1.9 — adjust to taste):

   ```text
   "STEAM_0:1:12345678" "" "abcdefghijklmnopqrstu" "ce" "" ""
   ```

   Fields: **`"auth"` `"password"` `"access flags"` `"account flags"` `"name"` `"contact"`**. Flag **`l`** is enough for the default language menu; **`abcdefghijklmnopqrstu`** is a common “full admin” set for stock plugins.

3. Apply without restart: join the server and run **`rcon amx_reloadadmins`** (after **`rcon_password …`**), **or** change map / restart the container.

### 2. In-game (as an admin)

- **`amxmodmenu`** — main **admin menu** (kick/ban/slap/client commands), provided stock **`admin.amxx`** / **`menufront.amxx`** are enabled.
- **`amx_help`** — lists many AMXX commands in the console.
- **`amx_langmenu`** — choose client language if **`multilingual.amxx`** is on.

If **`amxmodmenu`** does nothing, your user is not recognized as an admin: double-check **`users.ini`**, run **`amx_reloadadmins`**, and confirm your **`auth`** field matches how you connect (SteamID vs IP).

### 3. Server console / RCON

Same as single-player admin tools but remote:

```text
rcon_password YOUR_PASSWORD
rcon amx_help
rcon amx_reloadadmins
```

Useful when you are not in-game.

### 4. Adding or disabling plugins

- Stock list: **`addons/amxmodx/configs/plugins.ini`** inside the image (from the AMXX tarball). To change it persistently, add a read-only bind mount in **`docker-compose.yml`** to that path and place **`.amxx`** binaries under **`addons/amxmodx/plugins/`** (mount or custom image).
- After editing **`plugins.ini`**, **`rcon amx_plugins`** shows load state; **`rcon amx_pausecfg`** can pause/resume some plugins if **`pausecfg.amxx`** is loaded.

More detail: [AMX Mod X manual](https://wiki.alliedmods.net/Category:AMX_Mod_X) and plugin docs on [AlliedModders](https://www.alliedmods.net/).

---

## Metamod, ReUnion, and AMX Mod X

- **Metamod-r** is loaded from **`liblist.gam`** as upstream intended.
- **`addons/metamod/plugins.ini`** loads **ReUnion first**, then **AMXX** (`amxmodx_mm_i386.so`). ReUnion must precede AMXX for mixed Steam / non‑Steam clients.
- **AMXX 1.9** ships **`modules.ini`** / **`plugins.ini`** from the official base tarball (no **`reapi`** line in **`modules.ini`**). If you add third‑party modules that duplicate **ReGameDLL**’s ReAPI, expect **“Already loaded”** or instability — test before enabling.
- **Admins / menus / plugins:** see **[Using AMX Mod X](#using-amx-mod-x-amxx)** above; config file **`cstrike/amxmodx/users.ini`** ([Adding Admins](https://wiki.alliedmods.net/Adding_Admins_(AMX_Mod_X))).
- **Custom plugins:** bind‑mount **`addons/amxmodx/configs/plugins.ini`** (and drop **`.amxx`** files under **`addons/amxmodx/plugins/`**) or bake them in a derived image.
- If the server **segfaults on map load** after AMXX or plugin changes, try **ReUnion-only** Metamod (`plugins.ini` with just **`reunion_mm_i386.so`**) to isolate the cause.

---

## Ports and security

- **`SERVER_PORT`** (default **27016** on the host) maps to **27015/tcp** and **27015/udp** in the container (override in **`.env`**).
- **Change `RCON_PASSWORD`** before exposing the host to the internet; use a firewall and only open what you need.
- **VAC is off** (`secure 0` in **`liblist.gam`** and **`cstrike/config/server.cfg`**) so **Steam and non‑Steam** clients can connect with ReUnion; the server is **not** VAC‑secured.

---

## Troubleshooting

- **Cannot connect:** check `docker compose logs`, firewall, and that clients use the correct **UDP** port.
- **Client: “A connection to the Steam VAC server could not be made” (often during long map/mod downloads):** This comes from the **Steam client** failing to reach **Valve’s** VAC/auth endpoints over the internet — it is **not** your game server refusing the download and usually **not** something you fix in Docker. Your server runs **`secure 0`** (VAC off on the server), but the **Steam** app may still try to talk to Valve in the background. Fix on the **player PC**: allow **Steam** through firewall/antivirus (including outbound **HTTPS**), avoid aggressive VPNs for testing, restart Steam, check [Steam’s connectivity FAQ](https://help.steampowered.com/en/faqs/view/6C09-ED6F-3A21-D2AB). **Shorten in-game downloads** with **FastDL** (`sv_downloadurl` in **`cstrike/config/fastdl.cfg`**) so the client spends less time in a heavy “downloading resources” state (see **FastDL** above).
- **ARM Mac:** ensure Docker can run **linux/amd64** images; gameplay may be slower under emulation.
- **Respawn has no effect:** confirm logs show ReGameDLL / game DLL loading; `mp_forcerespawn` is a **ReGameDLL** cvar — do not strip ReGameDLL from a custom image.
- **`TEX_InitFromWad: couldn't open de_vegas.wad`:** Some community maps reference **`de_vegas.wad`**; minimal HLDS layers may not ship it. Copy **`de_vegas.wad`** from a full CS 1.6 install (Steam: `Half-Life/cstrike/de_vegas.wad`) into **`./data/cs16-game-assets/wads/`** (restart **`cs16`** / **`cs16-biohazard`**) so **`cs16-merge-game-assets`** layers it into **`cstrike/`**, or bind-mount it read-only in **`docker-compose.yml`**, e.g. `- ./cstrike/de_vegas.wad:/opt/steam/hlds/cstrike/de_vegas.wad:ro`.
- **`Steam validation rejected` (non‑Steam / cracked clients):** **`secure 0`** alone is not enough — ReHLDS still validates auth unless **ReUnion** accepts their client type. This image sets **`cid_NoSteam47 = 3`** and **`cid_NoSteam48 = 3`** in **`reunion.cfg`** (STEAM\_ IDs by IP) and **`AuthVersion = 2`**. Tune **`cid_*`** in **`reunion.cfg`** for your population; see [ReUnion](https://github.com/rehlds/ReUnion) and mount a custom file if needed.
- **`Segmentation fault` right after `Mapchange …`:** Try **ReUnion-only** Metamod (`plugins.ini` with just **`reunion_mm_i386.so`**) to confirm AMXX or a specific **`.amxx`** plugin. Ensure the image still uses **AMXX 1.9** from the Dockerfile (`AMXX_BASE_URL`); the stock **1.8.2** in the base layer is known to crash here.
- **Server dies when a Steam client joins:** Keep **`secure 0`** in **`cstrike/config/server.cfg`**; if you re-enable **`secure 1`**, you need a full Steam dedicated / VAC setup that survives in your container.
- **`engine_i486.so: cannot enable executable stack … Invalid argument`:** Usually indicates **glibc 2.41+** on the **runtime** HLDS layer vs **`engine_i486.so`**. This repo does not run **`apt upgrade`** on **`FROM blsalin/rehlds-cstrike`**. **Rebuild** **`cs16`** / **`cs16-biohazard`** from the pinned base. If hosts still glitch, **`GLIBC_TUNABLES=glibc.rtld.execstack=2`** in **`environment`** ([ReHLDS #1079](https://github.com/rehlds/ReHLDS/issues/1079)).

- **`zm_*` / `zb_*` maps wrong BSP / missing / crash:** Payload URLs must yield archives/BSP bytes (curl `-L`). Run **`compose --profile download-assets`**; fix **`image/game-assets/map-download-urls.manifest.txt`**, add **`.bsp`** via **`image/custom-maps/`** or **`./data/cs16-game-assets/maps/`**.

- **Biohazard / infection errors or pink models:** Merge the official pack into **`image/zombiemod/extra-assets/`** (not only **`biohazard.amxx`**) and **`docker compose build`**.

- **FastDL mismatches HLDS extras:** Restart **`fastdl`** after syncing **`./data/cs16-game-assets/`**; **`docker compose build cs16 fastdl`** when **`GAME_IMAGE`** blobs or **`docker/fastdl`** scripts change (**BuildKit** needed for **`RUN --mount`**).

---

## Credits

- Server base: [BLSAlin/rehlds-cstrike](https://github.com/BLSAlin/rehlds-cstrike) ([`ghcr.io/blsalin/rehlds-cstrike`](https://github.com/BLSAlin/rehlds-cstrike/pkgs/container/rehlds-cstrike))  
- Non‑Steam / mixed auth: [ReUnion](https://github.com/rehlds/ReUnion)  
- Respawn behaviour: [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS)  
- Classic zombie infection mod: [Biohazard v2.00 Beta 3b — AlliedModders](https://forums.alliedmods.net/showthread.php?t=68523)  
