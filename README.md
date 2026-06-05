# Counter-Strike 1.6 in Docker

[![Build and push to GHCR](https://github.com/7err0x/CS1.6_REHLDS-docker/actions/workflows/build-push-ghcr.yml/badge.svg)](https://github.com/7err0x/CS1.6_REHLDS-docker/actions/workflows/build-push-ghcr.yml)

**Free and open source** Docker deployment for Counter-Strike 1.6 dedicated servers supporting **multiple gamemodes**

**Included out of the box:** classic **respawn / deathmatch** and **Zombie Mod Classic — Biohazard** infection with:
- **lasermines** 
- napalm/freeze grenades 
- custom maps download script
- and FastDL for faster download times when connecting to server. 

**Other gamemodes** can be added by baking another `server.cfg` / `plugins.ini` profile in the [`Dockerfile`](Dockerfile) and a Compose service (same pattern as Biohazard). Feel free to fork this repo and add yours. Contribute by opening a PR.

This image comes with:

| Layer | Components | License (upstream) |
|-------|------------|-------------------|
| Engine | [ReHLDS](https://github.com/rehlds/ReHLDS) | GPLv3 |
| Game DLL | [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS) | GPLv3 / project license |
| Metamod | [Metamod-R](https://github.com/rehlds/Metamod-R) | GPLv3 |
| API | [ReAPI](https://github.com/rehlds/ReAPI) | GPLv3 |
| Auth | [ReUnion](https://github.com/rehlds/ReUnion) | GPLv3 |
| Modding | [AMX Mod X 1.9](https://github.com/alliedmodders/amxmodx) | GPLv3 |
| Infection mod | [Biohazard](https://forums.alliedmods.net/showthread.php?t=68523) + this repo’s ports | GPLv2+ |
| Lasermines | [Amxx-Laser-TripMine-Entity](https://github.com/AoiKagase/Amxx-Laser-TripMine-Entity) (Biohazard build) | See upstream |

**Repository licensing:** Original work in this repository (Dockerfiles, Compose files, scripts, configs, and plugin sources authored here) is licensed under **[GPL-3.0-or-later](LICENSE)**.

Upstream components listed above retain their own licenses. **Game assets** (maps, models, sounds, WADs, and similar content downloaded at build/runtime or supplied separately) are **not** covered by this repository’s license and remain subject to **[Valve](https://store.steampowered.com/subscriber_agreement/)** or other third-party terms. You must obtain and use those assets in compliance with the applicable agreements.

**Security-oriented defaults** (see [Ports and security](#ports-and-security)):

- Game containers run as non-root **`steam`**, **`read_only`** rootfs, **`cap_drop: ALL`**, **`no-new-privileges`**, and **`init: true`** (tini).
- Writable state uses named volumes (maps, bans, AMXX vault, etc.) plus host **`CS16_LOGS_HOST_DIR`** for HLDS log files; configs/plugins are baked from git.
- Biohazard profile optional **internal network** (no container internet egress) plus optional host **`biohazard-egress-firewall.sh`** rules.
- **`secure 0`** / **`reunion.cfg`** for controlled mixed Steam and non-Steam clients (not VAC-secured — change before public internet exposure).
- Change **`RCON_PASSWORD`** in **`.env`**; firewall published UDP/TCP ports.

**Requirements:** Docker with Compose, **x86_64** host (or Docker Desktop with **linux/amd64** emulation).

---

## Quick start

1. Copy the environment file and set at least **`RCON_PASSWORD`**. Compose reads project **`.env`** for variable substitution (optional but recommended):

   ```bash
   cp .env.example .env
   ```

2. Build the game image (needs **network**; first build runs **SteamCMD** and downloads HLDS + ReHLDS/ReGameDLL/ReAPI — often **10–30+ minutes** and **~2 GB**). Then start:

   ```bash
   docker compose build
   docker compose up -d
   ```

   Bump engine versions via **`.env`** / Compose build args (see [ReHLDS stack versions](#rehlds-stack-versions) and **`.env.example`**). Recipe: **`lib/hlds.install`**, stage **`hlds-base`** in [`Dockerfile`](Dockerfile).

3. In CS 1.6, open the console (`~`) and connect (use **`SERVER_PORT`** from **`.env`**; the default publish mapping is **27016** on the host → **27015** in the container):

   ```text
   connect 127.0.0.1:27016
   ```

4. Watch logs:

   ```bash
   docker compose logs -f
   ```

---

## Contents

- [ReHLDS stack versions](#rehlds-stack-versions)
- [Configuration](#configuration)
  - [Server name, game mode, welcome text, and announcements](#server-name-game-mode-welcome-text-and-announcements)
  - [Respawn and teams](#respawn-and-teams)
  - [Maps, downloadable extras, and FastDL](#maps-downloadable-extras-datacs16-game-assets-fastdl)
  - [Lasermines (Biohazard humans)](#lasermines-biohazard-humans)
  - [Zombie night vision](#zombie-night-vision)
  - [Map brightness and flashlights (Biohazard)](#map-brightness-and-flashlights-biohazard)
  - [Survivor ammo (`bh_ammo`)](#survivor-ammo-bh_ammo)
  - [Frost / napalm grenades (Biohazard ports)](#frost--napalm-grenades-zp50-derived-biohazard-ports)
  - [FastDL (faster first-join downloads)](#fastdl-faster-first-join-downloads)
- [Biohazard / old-school infection (optional profile)](#biohazard--old-school-infection-optional-profile)
  - [Biohazard AMXX plugin (included)](#1-biohazard-amxx-plugin-included)
  - [Compiling plugins locally (optional)](#2-compiling-plugins-locally-optional)
  - [Start the Biohazard server](#3-start-the-biohazard-server)
  - [RCON: infect a player or end the round (Biohazard)](#rcon-infect-a-player-or-end-the-round-biohazard)
  - [Other zombie / ReAPI stacks (not in this image)](#4-other-zombie--reapi-stacks-not-in-this-image)
- [Managing the server (Docker)](#managing-the-server-docker)
- [RCON (remote console)](#rcon-remote-console)
  - [GoldSrc vs Source (important)](#goldsrc-vs-source-important)
  - [From the CS 1.6 game client (simplest)](#from-the-cs-16-game-client-simplest)
  - [From the host without the game (UDP GoldSrc RCON)](#from-the-host-without-the-game-udp-goldsrc-rcon)
  - [Useful server commands](#useful-server-commands-via-rcon--or-server-console)
  - [Respawn and deathmatch (RCON)](#respawn-and-deathmatch-rcon)
  - [Map voting (stock AMXX)](#map-voting-stock-amxx)
- [Using AMX Mod X (AMXX)](#using-amx-mod-x-amxx)
  - [Make yourself an admin](#1-make-yourself-an-admin)
  - [In-game (as an admin)](#2-in-game-as-an-admin)
  - [Server console / RCON](#3-server-console--rcon)
  - [Adding or disabling plugins](#4-adding-or-disabling-plugins)
- [Metamod, ReUnion, and AMX Mod X](#metamod-reunion-and-amx-mod-x)
- [Ports and security](#ports-and-security)
  - [Container hardening](#container-hardening-cs16-cs16-biohazard)
  - [Biohazard egress lockdown](#biohazard-egress-lockdown-cs16-biohazard)
- [Troubleshooting](#troubleshooting)

---

## ReHLDS stack versions

The **`hlds-base`** stage downloads **Linux binary releases** from the official **[rehlds](https://github.com/rehlds)** GitHub organization (not legacy `dreamstalker` / `s1lentq` / `theAsmodai` URLs). Defaults are pinned in [`Dockerfile`](Dockerfile) and overridable via **`.env`** / **`docker-compose.yml`** build args.

| Build arg | Default (latest stable at pin time) | Release |
|-----------|-------------------------------------|---------|
| **`REHLDS_BUILD`** | **`3.15.0.896`** | [ReHLDS](https://github.com/rehlds/ReHLDS/releases/tag/3.15.0.896) |
| **`METAMOD_VERSION`** | **`1.3.0.149`** | [Metamod-R](https://github.com/rehlds/Metamod-R/releases/tag/1.3.0.149) |
| **`REGAMEDLL_VERSION`** | **`5.30.0.814`** | [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS/releases/tag/5.30.0.814) |
| **`REAPI_VERSION`** | **`5.29.0.358`** | [ReAPI](https://github.com/rehlds/ReAPI/releases/tag/5.29.0.358) |
| **`REUNION_VERSION`** | **`0.2.0.25`** | [ReUnion](https://github.com/rehlds/ReUnion/releases/tag/0.2.0.25) |

To upgrade after new [rehlds releases](https://github.com/rehlds), set the tags in **`.env`**, then rebuild:

```bash
docker compose build cs16
docker compose --profile biohazard up -d --force-recreate
```

### CI images (GHCR)

[`.github/workflows/build-push-ghcr.yml`](.github/workflows/build-push-ghcr.yml) polls for new **[ReHLDS](https://github.com/rehlds/ReHLDS/releases)** releases once a week (Sunday 03:17 UTC). When a new tag appears, it builds **`cs16-respawn`** and **`cs16-biohazard`** with the latest Metamod / ReGameDLL / ReAPI / ReUnion releases and pushes to **`ghcr.io/<owner>/cs16-respawn`** and **`cs16-biohazard`** tagged **`latest`** and **`<rehlds-tag>`** (e.g. **`3.15.0.896`**).

Enable **Actions** and set the package visibility to **public** (or use a PAT with **`read:packages`** to pull). Example **`.env`**:

```bash
CS16_RESPAWN_IMAGE=ghcr.io/7err0x/cs16-respawn:latest
CS16_BIOHAZARD_IMAGE=ghcr.io/7err0x/cs16-biohazard:latest
```

Manual rebuild: **Actions → Build and push to GHCR → Run workflow** (optional **force** to republish an existing ReHLDS tag).

**ReHLDS 3.15+** includes fixes for **executable stack** / glibc issues on newer hosts (see [ReHLDS #1157](https://github.com/rehlds/ReHLDS/pull/1157)) — you may no longer need **`GLIBC_TUNABLES=glibc.rtld.execstack=2`** in Compose.

---

## Configuration

| Item | Purpose |
|------|--------|
| `.env` | Port, slots, **RCON password**, start map, hostname (see `.env.example`). Optional **`AMXX_BASE_URL`** overrides the AMXX tarball used at **image build** time (Compose passes it as a build arg). |
| `cstrike/config/server.cfg` | Gameplay: **respawn**, teams vs FFA, round time, etc. Also **`secure 0`** / **`mp_consistency 0`** (VAC off; complements **`liblist.gam`**). |
| `cstrike/config/gamemode-biohazard.cfg` | **`cs16-biohazard`** boot **`+exec`**: **`mapcyclefile`** / flashlight. |
| `cstrike/config/server-biohazard.cfg` | Baked as **`server.cfg`** on **`cs16-biohazard` only** — **`mp_forcerespawn 0`**, **`mapcycle.biohazard.txt`**, **`amx_scrollmsg`** (see [Server name, game mode, welcome text, and announcements](#server-name-game-mode-welcome-text-and-announcements)). |
| `cstrike/amxmodx/users.ini` | **AMXX** admins (Steam ID / IP / flags). Mounted into **`addons/amxmodx/configs/users.ini`**. |
| `reunion.cfg` (in image) | ReUnion auth: **`AuthVersion = 2`**, **`cid_NoSteam47/48 = 3`** (STEAM\_ IDs by IP) so non‑Steam clients are not rejected. Mount your own copy over `/opt/steam/hlds/cstrike/reunion.cfg` if you need stricter rules. |

After editing `.env` or `cstrike/config/server.cfg`:

```bash
docker compose up -d --force-recreate
```

**Hostname** is applied from `.env` via the process command line; gameplay cvars live in `cstrike/config/server.cfg`.

### Server name, game mode, welcome text, and announcements

What players see comes from several places. After edits, use the **Apply changes** row below — hostname is the only item that usually needs **no image rebuild**.

| What players see | Where to edit | Apply changes |
|------------------|---------------|---------------|
| **Server name** (Internet / LAN browser list) | **`.env`**: `SERVER_HOSTNAME` (respawn **`cs16`**) or `BIOHAZARD_SERVER_HOSTNAME` (infection **`cs16-biohazard`**). Quotes if the name has spaces, e.g. `BIOHAZARD_SERVER_HOSTNAME="My ZM LAN"`. Set via `+hostname` in [`docker-compose.yml`](docker-compose.yml) — **not** `server.cfg`. | `docker compose up -d --force-recreate` (respawn) or `docker compose --profile biohazard up -d --force-recreate` |
| **Game / mode** string (browser **Game** column, e.g. `Biohazard`) | Biohazard cvar **`bh_gamedescription`** in [`image/zombiemod/extra-assets/addons/amxmodx/configs/bh_cvars.cfg`](image/zombiemod/extra-assets/addons/amxmodx/configs/bh_cvars.cfg) (add a line if missing, e.g. `bh_gamedescription "Infection ZM"`). Implemented in [`biohazard.sma`](image/zombiemod/extra-assets/addons/amxmodx/scripting/biohazard.sma) (`FM_GetGameDescription`). **Biohazard profile only.** | `docker compose build cs16-biohazard` then `docker compose --profile biohazard up -d --force-recreate` |
| **Welcome line** (chat once when you spawn alive) | [`image/zombiemod/extra-assets/addons/amxmodx/data/lang/biohazard.txt`](image/zombiemod/extra-assets/addons/amxmodx/data/lang/biohazard.txt) — English block `[en]`, key **`WELCOME_TXT`** (supports `#Version#` placeholder). **Biohazard only.** | Rebuild **`cs16-biohazard`** (lang files are baked from **`extra-assets/`**) |
| **Join MOTD** (first screen when you connect) | Same source as help: [`biohazard_motd_en.html`](image/zombiemod/extra-assets/addons/amxmodx/configs/biohazard_motd_en.html) is copied to **`cstrike/motd.txt`** at image build (`#Version#` filled from `biohazard.sma`). Replaces the default ReHLDS “You are playing Counter-Strike…” page. **Biohazard only.** | Rebuild **`cs16-biohazard`** |
| **Help / MOTD banner** (same HTML; chat: **`say /help`** or **`/help`**) | [`biohazard_motd_en.html`](image/zombiemod/extra-assets/addons/amxmodx/configs/biohazard_motd_en.html) and [`biohazard_motd_ro.html`](image/zombiemod/extra-assets/addons/amxmodx/configs/biohazard_motd_ro.html) (Romanian clients on `/help`). Edit HTML directly. **Biohazard only.** | Rebuild **`cs16-biohazard`** |
| **Other Biohazard chat/menu text** | [`addons/amxmodx/data/lang/biohazard.txt`](image/zombiemod/extra-assets/addons/amxmodx/data/lang/biohazard.txt) — **`[en]`** and **`[ro]`** only (menus, infection messages, welcome line). | Rebuild **`cs16-biohazard`** |
| **Scrolling chat announcements** (periodic center/chat reminder) | [`cstrike/config/server-biohazard.cfg`](cstrike/config/server-biohazard.cfg) — line **`amx_scrollmsg "…" 660`**. Second number = interval in **seconds** (`660` ≈ 11 minutes). Comment out the line to disable. Plugin: **`scrollmsg.amxx`** in [`image/zombiemod/plugins-biohazard.ini`](image/zombiemod/plugins-biohazard.ini). Respawn server: add the same line to [`cstrike/config/server.cfg`](cstrike/config/server.cfg) if you want it there too. | `docker compose build cs16-biohazard` (or `cs16-respawn`) then recreate the service |
| **Center-screen AMXX messages** (`imessage`) | **`imessage.amxx`** is enabled on Biohazard but **no default messages** are shipped. To use it, add message definitions (standard AMXX: **`amx_imessage`** in a cfg, or custom message config under **`addons/amxmodx/configs/`**) and bake or mount them. | Rebuild or mount your cfg; restart server |

**Examples**

`.env` (browser name):

```bash
BIOHAZARD_SERVER_HOSTNAME="ZM Biohazard — LAN"
```

`bh_cvars.cfg` (browser **Game** column):

```cfg
bh_gamedescription "Infection / Biohazard"
```

`biohazard.txt` (welcome chat):

```ini
WELCOME_TXT = Welcome! Infection round — type /help for rules. Biohazard v#Version#
```

`server-biohazard.cfg` (scroll reminder every 5 minutes):

```cfg
amx_scrollmsg "Say /help for rules. Humans: /lm for lasermines." 300
```

**Note:** `cstrike/config/*.cfg` and `extra-assets/` are **copied into the image at build time** (see [`Dockerfile`](Dockerfile)). Editing them on the host does not affect a running container until you **`docker compose build`** the matching image. Hostname in **`.env`** is the exception (read at container start).

### Respawn and teams

The **`cs16`** service (profile **`respawn`**) bakes **`configs/profiles/plugins-respawn.ini`** as the only **`plugins.ini`** (AMXX also auto-loads any **`configs/plugins-*.ini`** — profile templates must not use that prefix in **`configs/`**). No Biohazard / lasermines plugins; **`respawn_defaults.amxx`** resets map lighting; **`+exec config/gamemode-respawn.cfg`**; join MOTD from **`respawn_motd_en.html`**; separate **`config.cfg`** / AMXX **vault** under **`hlds-meta-respawn/`** and **`amxx-data-respawn/vault/`**.

In `cstrike/config/server.cfg`:

- **`mp_forcerespawn 1`** — turns on ReGameDLL **respawn / deathmatch-style** behaviour.
- **`mp_respawn_immunitytime 3`** — **3 seconds** spawn protection after respawn (ReGameDLL; **`0`** disables). Tune in [`cstrike/config/server.cfg`](cstrike/config/server.cfg) with **`mp_respawn_immunity_effects`** / **`mp_respawn_immunity_force_unset`**.
- **`mp_infinite_ammo 2`** — infinite **reserve** ammo (reload without running out). Use **`1`** for infinite **clip** (no reload needed).
- **`mp_freeforall 0`** — keep **CT vs T**. Set to **`1`** for **everyone vs everyone**.

More ReGameDLL variables are documented in the [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS) project (see `dist/game.cfg` in that repo for defaults and comments).

### Maps, downloadable extras (`./data/cs16-game-assets/`), FastDL

| Path | Role |
|------|------|
| [`Dockerfile`](Dockerfile) | **3 stages:** **`amxx-build`** (compile all pack **`.sma`**), **`hlds-base`** (SteamCMD + ReHLDS stack; pins in file / **`.env`**), **`cs16`** (**mapcycle***, **AMXX 1.9**, **ReUnion**, Biohazard). **`lib/hlds.install`** drives Steam app **90** `steam_legacy`. **`zm_*` packs**: **`download-game-assets`** → **`./data/cs16-game-assets/`** (below). |
| [`lib/hlds.install`](lib/hlds.install) | SteamCMD script: install CS 1.6 dedicated (**`app_update 90 -beta steam_legacy`**). |
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
| [`docker-compose.yml`](docker-compose.yml) **`fastdl`** (profile **`fastdl`**) | **Nginx**: at **startup** merges game image + **`./data/cs16-game-assets`**, then **`compress-bz2.sh`** writes **`.bz2`** sidecars (GoldSrc clients fetch **`file.ext.bz2`** when present). **`restart`** after new extras; **`build fastdl`** after game image changes. |
| [`docker/fastdl/Dockerfile`](docker/fastdl/Dockerfile) | **`nginx:alpine`** + **bzip2**, BuildKit snapshot of **`GAME_IMAGE`** `cstrike/`, **`compress-bz2.sh`** at build and via **`entrypoint.sh`**. |
| [`docker/fastdl/compress-bz2.sh`](docker/fastdl/compress-bz2.sh) | **`bzip2 -9 -k`** sidecars for **`.bsp`**, **`.wad`**, **`.mdl`**, **`.wav`**, **`.spr`**, **`.tga`** ≥ **`CS16_FASTDL_BZ2_MIN_BYTES`** (default **4096**). Skips unchanged files if the original is not newer than **`.bz2`**. |
| [`docker/fastdl/default.conf`](docker/fastdl/default.conf) | Nginx: static **`.bz2`** and raw files, **`gzip off`**, **`application/octet-stream`**. |
| [`image/zombiemod/plugins-respawn.ini`](image/zombiemod/plugins-respawn.ini) | AMXX list for **respawn**: stock admin / mapchooser stack, **`respawn_defaults.amxx`**, **`bio_crosshair_id.amxx`** (no **`biohazard.amxx`**). |
| [`cstrike/config/gamemode-respawn.cfg`](cstrike/config/gamemode-respawn.cfg) | Boot **`+exec`** on **`cs16`**: **`mapcycle.txt`**, **`mp_forcerespawn 1`**. |
| [`image/zombiemod/extra-assets/.../respawn_motd_en.html`](image/zombiemod/extra-assets/addons/amxmodx/configs/respawn_motd_en.html) | Join MOTD for respawn (baked as **`cstrike/motd.txt`** when **`CS16_PLUGINS_INI=plugins-respawn.ini`**). |
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
- A **scrolling chat reminder** is set in **`cstrike/config/server-biohazard.cfg`** (`amx_scrollmsg`) — edit interval and text there (see [Server name, game mode, welcome text, and announcements](#server-name-game-mode-welcome-text-and-announcements)). In-game **`say lasermine`** uses **`addons/amxmodx/data/lang/lasermine.txt`** (`REFER` line).

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

**Plugin must be loaded:** **`customflashlight.amxx`** is compiled at image build but is **not** enabled in **`image/zombiemod/plugins-biohazard.ini`** by default. Add a line **`customflashlight.amxx`** (after **`biohazard.amxx`**) and restart **`cs16-biohazard`** so **`flashlight_*`** cvars do anything. With **`flashlight_custom 0`**, only stock **`mp_flashlight`** applies and **`flashlight_radius`** is ignored.

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

1. Build **game**, then **FastDL** (**`docker compose build cs16 fastdl`**). Changing **`GAME_IMAGE`** content or **`docker/fastdl/`** scripts requires **`build fastdl`**. Adding files under **`./data/cs16-game-assets/`** → **`restart fastdl`** (entrypoint re-merges and creates missing **`.bz2`** sidecars; first start after large map adds can take a minute while **bzip2** runs).
2. Start FastDL: **`docker compose --profile fastdl up -d`** ( **`FASTDL_HTTP_PORT`**, default **8080** ).
3. In **`cstrike/config/fastdl.cfg`**, uncomment **`sv_downloadurl`** with a **trailing slash** (LAN example: **`http://192.168.1.10:8080/`**).
4. Restart game containers if you only changed **`fastdl.cfg`**: **`docker compose restart cs16`** (and **`cs16-biohazard`** if used).

**Option B — any other static host (CDN, VPS nginx, S3, …):** same path layout under the URL; set **`sv_downloadurl`** accordingly.

**Reload config only:** edit **`fastdl.cfg`** then **`docker compose restart cs16`** (and **`cs16-biohazard`** if applicable); no image rebuild.

**`.bz2` sidecars (automatic):** The **`fastdl`** image runs **`docker/fastdl/compress-bz2.sh`** at **build** and on each **container start**, creating **`maps/foo.bsp.bz2`** (etc.) next to originals. GoldSrc clients request the **`.bz2`** URL when it exists — much smaller than raw BSP/WAD. Originals stay on disk as fallback. Override minimum size with **`CS16_FASTDL_BZ2_MIN_BYTES`** on the **`fastdl`** service (Compose). Keep **`sv_allowdownload 1`** in **`fastdl.cfg`** so the in-game channel still works if HTTP misses a file.

**Rebuild** after changing **`image/mapcycle*.txt`**, **`Dockerfile`**, or files under **`image/custom-maps/`**. **`image/game-assets/`** URL changes only require re-running **`download-assets`** (no image rebuild unless you change how **`download-game-assets`** is built):

```bash
docker compose build --no-cache
docker compose up -d --force-recreate
```

If a download URL breaks, edit **`image/game-assets/map-download-urls.manifest.txt`**, use **`MANIFEST=…`** override, paste BSPs/WADs into **`./data/cs16-game-assets/`**, or bake BSPs via **`image/custom-maps/`**.

---

## Biohazard / old-school infection (optional profile)

This profile listens on **`BIOHAZARD_SERVER_PORT`** (default **27017**). **`zm_*`** maps live in **`./data/cs16-game-assets/maps/`** — populate with **`compose --profile download-assets`**; **`BIOHAZARD_START_MAP`** defaults to **`cs_estate`** (stock) so you can boot before syncing HL2GO / GameBanana packs. Pack **`.amxx`** plugins are compiled in the image from **`extra-assets/.../scripting/`** — expand **`extra-assets/`** for vendor models/sounds.

The profile merges **`plugins-biohazard.ini`**, **`server-biohazard.cfg`**, and uses **`docker-compose.yml`** **`entrypoint`** (**`cs16-merge-game-assets-entrypoint.sh`**) ahead of **`hlds_run`** so **`./data/cs16-game-assets`** is layered into **`cstrike/`** each boot.

### 1. Biohazard AMXX plugin (included)

The image **compiles every pack `.sma`** under **`image/zombiemod/extra-assets/addons/amxmodx/scripting/`** in stage **`amxx-build`** (patched **`biohazard.sma`**, **lasermine**, grenades, etc.) and copies the resulting **`.amxx`** into the final image — **no plugin binaries are committed** (see **`.gitignore`**). For the **full Biohazard public pack** (models, sounds, **zombie classes**, etc.), obtain **Biohazard v2.00 Beta 3b** from the official thread and merge assets into **`image/zombiemod/extra-assets/`** (see **`image/zombiemod/extra-assets/README.txt`**).

- [Biohazard v2.00 Beta 3b (Zombie Mod) — AlliedModders](https://forums.alliedmods.net/showthread.php?t=68523)

**Quick path for Docker (assets only if you do not have the pack yet):**

1. Extract the pack on your PC and merge **`models/`**, **`sound/`**, **`sprites/`**, extra **`addons/amxmodx/`** files you need into **`image/zombiemod/extra-assets/`** so its top-level folders match **`cstrike/`**.
2. Rebuild: **`docker compose build`** and **`docker compose --profile biohazard up -d --force-recreate`**.

### 2. Compiling plugins locally (optional)

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

5. The output is **`biohazard.amxx`** in that directory. Normally you only **`docker compose build`** — stage **`amxx-build`** recompiles all pack **`.sma`** automatically.

**On Windows:** use the **Windows** AMXX base package from the same release, open **`compile.exe`** or run **`amxxpc.exe`** from the scripting folder with **`biohazard.sma`** and the same **`biohazard.cfg`** / **`data/lang/biohazard.txt`** layout under your local AMXX tree.

#### Docker build cache (`.sma` vs `docker/amxx-compile-all.sh`)

The image has three stages: **`amxx-build`** (runs **`docker/amxx-compile-all.sh`**), **`hlds-base`**, **`cs16`**. Docker reuses a cached layer until a file used in that layer changes.

| You changed | Usually enough |
|-------------|----------------|
| Any **`image/zombiemod/extra-assets/.../scripting/*.sma`**, **`*.cfg`**, or **`include/`** | **`docker compose build cs16-biohazard`** (or **`cs16`**) — invalidates **`amxx-build`** from the **`COPY`** of sources onward |
| **`docker/amxx-compile-all.sh`** only (plugin list, compile order) | **Must** bust **`amxx-build`** cache — a normal build often **skips** the compile step because the **`.sma` `COPY` checksums are unchanged** |
| **`Dockerfile`** steps in **`cs16`** only (mapcycles, configs, assets) | **`docker compose build`** — **`hlds-base`** / **`amxx-build`** stay cached if untouched |

**Force `amxx-build` to run again** (after editing **`amxx-compile-all.sh`**):

```bash
docker buildx build \
  --file Dockerfile \
  --target cs16 \
  --no-cache-filter amxx-build \
  --no-cache-filter cs16 \
  --tag cs16-respawn:latest \
  --load \
  .
docker compose build cs16-biohazard
docker compose --profile biohazard up -d --force-recreate cs16-biohazard
```

(`docker compose build --no-cache` rebuilds **every** stage including slow **SteamCMD** — avoid unless you need a full clean build.)

Use that when you changed **`cs16`** layers (mapcycles, **`extra-assets`** merge, ReUnion pins) but **not** when you changed **`amxx-compile-all.sh`** or **`.sma`** sources.

### 3. Start the Biohazard server

```bash
mkdir -p data/cs16-game-assets
docker compose --profile download-assets run --rm download-game-assets
docker compose build --pull
docker compose --profile biohazard up -d
```

- **Default listen:** **`BIOHAZARD_SERVER_PORT`** (**27017** → container **27015**). Connect from CS, for example: **`connect 127.0.0.1:27017`**.
- **Start map:** **`BIOHAZARD_START_MAP`** (default **`cs_estate`** — dark indoor stock map).
- **Hostname / RCON:** **`BIOHAZARD_SERVER_HOSTNAME`**, **`BIOHAZARD_RCON_PASSWORD`** (see **`.env.example`**). Use **`BIOHAZARD_RCON_PASSWORD`** (not **`RCON_PASSWORD`**) when sending **`rcon`** to this container on **`BIOHAZARD_SERVER_PORT`** (default **27017**).

The profile mounts **`plugins-biohazard.ini`**, **`server-biohazard.cfg`**, and uses **`docker-compose`** so **`command`** retains **`./hlds_run … +map`** (no baked **`+map de_dust2`** override).

### RCON: infect a player or end the round (Biohazard)

Join **`cs16-biohazard`**, set the password, then prefix admin commands with **`rcon`** (same flow as [RCON (remote console)](#rcon-remote-console) below).

```text
rcon_password YOUR_BIOHAZARD_RCON_PASSWORD
rcon status
```

#### Infect someone (`amx_infect`)

Biohazard registers **`amx_infect`** in **`biohazard.sma`** (requires **AMXX `ADMIN_BAN`** — flag **`d`** in **`cstrike/amxmodx/users.ini`**, or use RCON / server console which runs as full access):

```text
rcon amx_infect PlayerName
rcon amx_infect #4
```

| Argument | Example |
|----------|---------|
| Partial name | **`rcon amx_infect rob`** |
| **`#userid`** | From **`rcon status`** (first column) — **`rcon amx_infect #3`** |

**When it works:**

- The infection round has **started** (after **`bh_starttime`**, default **15** seconds from round start). Otherwise the server prints *Game has not started yet.*
- Target is **connected**, **alive**, and **not already** a zombie.
- **`bh_maxzombies`** (default **31**) is not exceeded and at least **two** humans are alive. If you hit *Max zombies reached*, slay a zombie first or **`rcon bh_maxzombies 32`**.

There is **no** built-in **`amx_cure`** / **`amx_human`** in this Biohazard build — only **`amx_infect`**.

#### Finish / restart the round

Biohazard does not add a dedicated “end round” admin command. Use engine / stock AMXX tools:

| Goal | RCON example | Notes |
|------|----------------|-------|
| **Restart round quickly** | **`rcon sv_restart 1`** | Standard HLDS; starts a fresh round (new infection countdown). |
| **Zombies win (survivors dead)** | **`rcon amx_slay @ct`** | Survivors are **CT**; triggers *Zombies win!* |
| **Survivors win (zombies dead)** | **`rcon amx_slay @t`** | Zombies are **T**; triggers *Survivors win!* |
| **Slay one player** | **`rcon amx_slay PlayerName`** | Stock **`admincmd.amxx`** (in **`plugins-biohazard.ini`**). |
| **Next map / hard reset** | **`rcon changelevel zm_dust`** | Use a map from **`mapcycle.biohazard.txt`**. |

**`amx_slay`** needs admin access (flag **`d`** or full flags in **`users.ini`**, or RCON).

**Infect everyone manually:** repeat **`rcon amx_infect`** on each survivor, or slay CTs for a zombie win. Rounds also end when one side is wiped or **`mp_timelimit`** expires (**`server-biohazard.cfg`**).

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

**Counter-Strike 1.6** uses the **GoldSrc / HLDS** remote console: **UDP** to the **same port players use** (**`SERVER_PORT`** from **`.env`**, default **27016**; HLDS binds it via **`+port`** in **`docker-compose.yml`**).

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

**Biohazard profile (`cs16-biohazard`):** infect / round control — **`amx_infect`**, **`amx_slay @ct`** / **`@t`**, **`sv_restart 1`** — see [RCON: infect a player or end the round (Biohazard)](#rcon-infect-a-player-or-end-the-round-biohazard). Use **`BIOHAZARD_RCON_PASSWORD`** on port **`BIOHAZARD_SERVER_PORT`** (default **27017**).

### Respawn and deathmatch (RCON)

**ReGameDLL** uses **`mp_forcerespawn`** so players **respawn** instead of spectating until round end. Defaults are in **`cstrike/config/server.cfg`**; from the client console (after **`rcon_password`**):

| Goal | `rcon` examples |
|------|-----------------|
| **Respawn DM, teams (CT vs T)** | `rcon mp_forcerespawn 1` · `rcon mp_freeforall 0` |
| **Spawn immunity (seconds)** | `rcon mp_respawn_immunitytime 3` (`0` = off) · `mp_respawn_immunity_effects 1` · `mp_respawn_immunity_force_unset 1` |
| **Infinite ammo (reload)** | `rcon mp_infinite_ammo 2` (reserve) · `1` = infinite clip |
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

- **`SERVER_PORT`** (default **27016**) is the game and RCON port on the host and inside the container (**`+port`** + publish mapping in **`docker-compose.yml`**; override in **`.env`**).
- **Change `RCON_PASSWORD`** before exposing the host to the internet; use a firewall and only open what you need.
- **VAC is off** (`secure 0` in **`liblist.gam`** and **`cstrike/config/server.cfg`**) so **Steam and non‑Steam** clients can connect with ReUnion; the server is **not** VAC‑secured.

### Container hardening (`cs16`, `cs16-biohazard`)

Both game services use:

| Option | Effect |
|--------|--------|
| **`user: steam`** | Process runs as the image **`steam`** user (not root). |
| **`init: true`** | Tiny init (**tini**) reaps zombie processes from **`hlds_run`**. |
| **`read_only: true`** | Root filesystem is read-only; volumes and host log bind mounts hold runtime writes. |
| **`cap_drop: [ALL]`** | Drops Linux capabilities (game **`SERVER_PORT`** is unprivileged inside the container). |
| **`security_opt: no-new-privileges:true`** | Blocks privilege escalation via setuid binaries. |
| **`tmpfs`** | Writable **`/tmp`** and **`/run`**. |

**Writable named volumes** (created automatically on first **`docker compose up`** — no host **`mkdir`** / **`chmod`**):

**`./data/cs16-game-assets`** (community maps/sounds/WADs), **`cs16-state`** (bans, per-profile **`config.cfg`**, AMXX vault, etc.). **HLDS log files** under **`./data/cs16-logs/{respawn,biohazard}/`**.

**Configs and plugins** are **baked into the image** from **`cstrike/`** and **`image/zombiemod/`** (edit in git, then **`docker compose build`**). Populate game assets with:

```bash
mkdir -p data/cs16-game-assets
docker compose --profile download-assets run --rm download-game-assets
docker compose build cs16-biohazard
docker compose --profile biohazard up -d --force-recreate
```

**Respawn** and **Biohazard** are separate images (**`ghcr.io/7err0x/cs16-respawn:latest`**, **`ghcr.io/7err0x/cs16-biohazard:latest`**) with different **`CS16_SERVER_CONFIG`** / **`CS16_PLUGINS_INI`** build args.

**Logs:** HLDS writes **`L*.log`** under **`data/cs16-logs/respawn/`** and **`data/cs16-logs/biohazard/`** (relative to the repo; created on first **`cs16-state-init`**). Container stdout: **`docker compose logs -f cs16`** / **`cs16-biohazard`**. Optional host logrotate: **`sudo ./docker/install-logrotate.sh`** (defaults to **`$REPO_ROOT/data/cs16-logs`**).

### Biohazard egress lockdown (`cs16-biohazard`)

The **biohazard** service uses an **internal** Docker network (**`cs16-internal-network`**) so the container has **no default route to the internet**. **Published ports** (**`BIOHAZARD_SERVER_PORT`**, default **27017**) still accept **incoming** player and RCON traffic; **FastDL** is fetched by **clients** from the **`fastdl`** service, not by the game container.

**Trade-offs:** Steam **master-server heartbeats** (server browser listing) and any **plugin-initiated outbound HTTP** are blocked. **Direct connect** (`connect host:port`) continues to work.

Optional **host-level** stateful rules (defense in depth; allows **ESTABLISHED/RELATED** replies, drops **new** outbound from the container IP):

```bash
docker compose --profile biohazard up -d cs16-biohazard
sudo ./docker/biohazard-egress-firewall.sh apply
sudo ./docker/biohazard-egress-firewall.sh status
# after container recreate (IP may change):
sudo ./docker/biohazard-egress-firewall.sh remove
sudo ./docker/biohazard-egress-firewall.sh apply
sudo ./docker/biohazard-egress-firewall.sh remove   # tear down
```

Rules live in iptables chain **`CS16-BIOHAZARD-EGRESS`**, jumped from **`DOCKER-USER`**. Re-run **`apply`** whenever you **`--force-recreate`** the biohazard container (its IP changes).

### Rootless Docker (UDP)

GoldSrc needs **bidirectional UDP** with correct client source addresses. Rootless Docker’s **default** RootlessKit stack (`gvisor-tap-vsock` + `builtin` port driver) often allows **`connect 127.0.0.1:27016`** but **fails from the LAN** — this is a **known rootless networking constraint**, not an HLDS bug.

**Recommended:** switch to **passt** (`pasta`) + **`implicit`** port driver:


**Alternatives:** host networking (`docker-compose.rootless-hostnet.yml`) or rootful Docker.


---

## Troubleshooting

- **Cannot connect:** check `docker compose logs`, firewall, and that clients use the correct **UDP** port.
- **Client: “A connection to the Steam VAC server could not be made” (often during long map/mod downloads):** This comes from the **Steam client** failing to reach **Valve’s** VAC/auth endpoints over the internet — it is **not** your game server refusing the download and usually **not** something you fix in Docker. Your server runs **`secure 0`** (VAC off on the server), but the **Steam** app may still try to talk to Valve in the background. Fix on the **player PC**: allow **Steam** through firewall/antivirus (including outbound **HTTPS**), avoid aggressive VPNs for testing, restart Steam, check [Steam’s connectivity FAQ](https://help.steampowered.com/en/faqs/view/6C09-ED6F-3A21-D2AB). **Shorten in-game downloads** with **FastDL** (`sv_downloadurl` in **`cstrike/config/fastdl.cfg`**) so the client spends less time in a heavy “downloading resources” state (see **FastDL** above).
- **ARM Mac:** ensure Docker can run **linux/amd64** images; gameplay may be slower under emulation.
- **Respawn has no effect:** confirm logs show ReGameDLL / game DLL loading; `mp_forcerespawn` is a **ReGameDLL** cvar — do not strip ReGameDLL from a custom image.
- **`TEX_InitFromWad: couldn't open de_vegas.wad`:** Some community maps reference **`de_vegas.wad`**; minimal HLDS layers may not ship it. Copy **`de_vegas.wad`** from a full CS 1.6 install (Steam: `Half-Life/cstrike/de_vegas.wad`) into **`./data/cs16-game-assets/wads/`** (restart **`cs16`** / **`cs16-biohazard`**) so **`cs16-merge-game-assets`** layers it into **`cstrike/`**, or bind-mount it read-only in **`docker-compose.yml`**, e.g. `- ./cstrike/de_vegas.wad:/opt/steam/hlds/cstrike/de_vegas.wad:ro`.
- **`Steam validation rejected` (non‑Steam / cracked clients):** **`secure 0`** alone is not enough — ReHLDS still validates auth unless **ReUnion** accepts their client type. This image sets **`cid_NoSteam47 = 3`** and **`cid_NoSteam48 = 3`** in **`reunion.cfg`** (STEAM\_ IDs by IP) and **`AuthVersion = 2`**. Tune **`cid_*`** in **`reunion.cfg`** for your population; see [ReUnion](https://github.com/rehlds/ReUnion) and mount a custom file if needed.
- **`Segmentation fault` right after `Mapchange …`:** Try **ReUnion-only** Metamod (`plugins.ini` with just **`reunion_mm_i386.so`**) to confirm AMXX or a specific **`.amxx`** plugin. Ensure the image still uses **AMXX 1.9** from the Dockerfile (`AMXX_BASE_URL`); do not reinstall AMXX **1.8.x** into **`hlds-base`**.
- **Server dies when a Steam client joins:** Keep **`secure 0`** in **`cstrike/config/server.cfg`**; if you re-enable **`secure 1`**, you need a full Steam dedicated / VAC setup that survives in your container.
- **`engine_i486.so: cannot enable executable stack … Invalid argument`:** Usually **glibc 2.41+** vs **`engine_i486.so`**. **`hlds-base`** uses **`debian:bookworm-slim`** without a full **`apt upgrade`**. Rebuild the image; if needed set **`GLIBC_TUNABLES=glibc.rtld.execstack=2`** on the service ([ReHLDS #1079](https://github.com/rehlds/ReHLDS/issues/1079)).
- **SteamCMD / HLDS install fails during `docker compose build`:** Needs outbound HTTPS; retry **`docker compose build`**. Valve CDN or **`steam_legacy`** beta changes may require editing **`lib/hlds.install`**.

- **`zm_*` / `zb_*` maps wrong BSP / missing / crash:** Payload URLs must yield archives/BSP bytes (curl `-L`). Run **`compose --profile download-assets`**; fix **`image/game-assets/map-download-urls.manifest.txt`**, add **`.bsp`** via **`image/custom-maps/`** or **`./data/cs16-game-assets/maps/`**.

- **Biohazard / infection errors or pink models:** Merge the official pack into **`image/zombiemod/extra-assets/`** (models/sounds/configs, not only the plugin source) and **`docker compose build`**.

- **FastDL mismatches HLDS extras:** Restart **`fastdl`** after syncing **`./data/cs16-game-assets/`**; **`docker compose build cs16 fastdl`** when **`GAME_IMAGE`** blobs or **`docker/fastdl`** scripts change (**BuildKit** needed for **`RUN --mount`**).

---


