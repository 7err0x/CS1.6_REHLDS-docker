# Counter-Strike 1.6 in Docker (respawn / deathmatch mode)

This stack runs a **Counter-Strike 1.6** dedicated server using a **small custom image** built `FROM` the upstream [rehlds-cstrike](https://github.com/BLSAlin/rehlds-cstrike) container (default **`ghcr.io/blsalin/rehlds-cstrike:edge`** — see [GHCR package](https://github.com/BLSAlin/rehlds-cstrike/pkgs/container/rehlds-cstrike)). The **Dockerfile** overlays **AMX Mod X 1.9** (Linux base tarball from [AlliedModders releases](https://github.com/alliedmodders/amxmodx/releases)) because the upstream image’s **1.8.2** build **segfaults** after map load on this stack. It also installs **[ReUnion](https://github.com/rehlds/ReUnion)** and configures **Metamod-r** to load **ReUnion** then **AMXX** (`plugins.ini`). **ReGameDLL** stays active for **respawn** (`mp_forcerespawn` in `cstrike/config/server.cfg`). **`liblist.gam`** keeps **`secure "0"`** and **`cstrike/config/server.cfg`** sets **`secure 0`** so **VAC is off** for broad client compatibility (Steam + typical non‑Steam builds). The image bakes a **respawn-oriented mapcycle** and **community FY / aim / AWP maps**.

**Requirements:** Docker with Compose, **x86_64** host (or Docker Desktop with **linux/amd64** emulation). **Steam and non‑Steam** clients can join when ReUnion + `secure 0` are in effect (see **`reunion.cfg`** baked into the image).

---

## Quick start

1. Copy the environment file and set at least **`RCON_PASSWORD`**. Compose reads project **`.env`** for variable substitution (optional but recommended):

   ```bash
   cp .env.example .env
   ```

2. Build the game image (needs **network** once, to download `.bsp` files listed in `image/scripts/bake-community-maps.sh`), then start:

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

### Maps and mapcycle (baked image)

| Path | Role |
|------|------|
| [`Dockerfile`](Dockerfile) | Bakes maps/WADs, downloads **AMXX 1.9** base (`ARG AMXX_BASE_URL`), installs **[ReUnion](https://github.com/rehlds/ReUnion)** (`ARG REUNION_VERSION`), **`plugins.ini`** = ReUnion + AMXX, **`secure "0"`** in **`liblist.gam`**, patches **`reunion.cfg`** for mixed Steam / no‑Steam clients. |
| [`image/mapcycle.txt`](image/mapcycle.txt) | Rotation tuned for **respawn**: small **fy_** / **aim_** / **awp_** arenas first, then medium **stock** maps (`de_*`, `cs_*`) that ship with HLDS. |
| [`image/scripts/bake-community-maps.sh`](image/scripts/bake-community-maps.sh) | At **build** time, `curl`s **`fy_iceworld`**, **`aim_map`**, **`fy_snow`**, **`awp_india`** from a public map mirror (`MAP_DOWNLOAD_BASE`, default `https://www.csboost.eu/downloads/maps`), then installs **`de_vegas.wad`** into `cstrike/` (zip from HL2GO; override with `DE_VEGAS_WAD_ZIP_URL` if needed). |
| [`image/custom-maps/`](image/custom-maps/) | Optional: add your own **`*.bsp`** here before `docker compose build`; they are **copied last** and can replace files with the same name. |

**Rebuild** after changing the mapcycle, the bake script, or files under `image/custom-maps/`:

```bash
docker compose build --no-cache
docker compose up -d --force-recreate
```

If the mirror is down, point the build at another HTTP **FastDL**-style tree that stores the same filenames, or place `.bsp` files only under `image/custom-maps/` and trim `bake-community-maps.sh` to skip downloads.

---

## Managing the server (Docker)

| Action | Command |
|--------|--------|
| Start (background) | `docker compose up -d` |
| Stop | `docker compose down` |
| Restart | `docker compose restart` |
| Logs (follow) | `docker compose logs -f` |
| Status | `docker compose ps` |

The container is named **`cs16-respawn0`** (`container_name` in Compose). One-off shell as the steam user (for debugging):

```bash
docker exec -it cs16-respawn0 bash
```

Game files live under `/opt/steam/hlds/cstrike` inside the container.

---

## RCON (remote console)

### GoldSrc vs Source (important)

**Counter-Strike 1.6** uses the **GoldSrc / HLDS** remote console: **UDP** to the **same port players use** (inside the container that is **27015**; on the host it is whatever you set in **`.env`** as **`SERVER_PORT`**, default **27015**).

That is **not** the **Source engine RCON** protocol (**TCP**, different packet layout). Docker images built around **Source RCON** will **not** talk to this server. In particular, **[`outdead/rcon`](https://hub.docker.com/r/outdead/rcon)** ([gorcon/rcon-cli](https://github.com/gorcon/rcon-cli)) targets **Source / Web / Telnet** RCON for games like **CS:GO** — **do not use it for CS 1.6**.

### From the CS 1.6 game client (simplest)

1. Set **`RCON_PASSWORD`** in **`.env`** and **`docker compose up -d --force-recreate`** so the server uses it (Compose passes **`+rcon_password`** on startup).
2. Join the server from CS 1.6.
3. Open the console (**`~`**) and run:

   ```text
   rcon_password YOUR_PASSWORD_HERE
   rcon status
   rcon changelevel fy_snow
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
| `mp_forcerespawn 1` | Enable respawn |
| `mp_freeforall 1` | Free-for-all |
| `mp_timelimit 45` | Map time limit (minutes) |
| `sv_restart 1` | Quick restart |
| `rcon_password ...` | Change RCON password at runtime (also set in `.env` for next restart) |
| `amx_reloadadmins` | Reload **`users.ini`** after you edit AMXX admins on the host |

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

- **27015/tcp** and **27015/udp** are published by default (override with `SERVER_PORT` in `.env`).
- **Change `RCON_PASSWORD`** before exposing the host to the internet; use a firewall and only open what you need.
- **VAC is off** (`secure 0` in **`liblist.gam`** and **`cstrike/config/server.cfg`**) so **Steam and non‑Steam** clients can connect with ReUnion; the server is **not** VAC‑secured.

---

## Troubleshooting

- **Cannot connect:** check `docker compose logs`, firewall, and that clients use the correct **UDP** port.
- **ARM Mac:** ensure Docker can run **linux/amd64** images; gameplay may be slower under emulation.
- **Respawn has no effect:** confirm logs show ReGameDLL / game DLL loading; `mp_forcerespawn` is a **ReGameDLL** cvar — do not strip ReGameDLL from a custom image.
- **`TEX_InitFromWad: couldn't open de_vegas.wad`:** Several community maps (including **`fy_iceworld`**) still reference Valve’s **`de_vegas.wad`** textures, but many minimal HLDS installs do not ship that file. The bake script now downloads **`de_vegas.wad`** into `cstrike/` during **`docker compose build`**. Rebuild with `docker compose build --no-cache` and start again. If the download mirror fails, copy **`de_vegas.wad`** from a full CS 1.6 install (Steam: `Half-Life/cstrike/de_vegas.wad`) onto the host and add a read-only bind mount in `docker-compose.yml`, for example: `- ./cstrike/de_vegas.wad:/opt/steam/hlds/cstrike/de_vegas.wad:ro`.
- **`Steam validation rejected` (non‑Steam / cracked clients):** **`secure 0`** alone is not enough — ReHLDS still validates auth unless **ReUnion** accepts their client type. This image sets **`cid_NoSteam47 = 3`** and **`cid_NoSteam48 = 3`** in **`reunion.cfg`** (STEAM\_ IDs by IP) and **`AuthVersion = 2`**. Tune **`cid_*`** in **`reunion.cfg`** for your population; see [ReUnion](https://github.com/rehlds/ReUnion) and mount a custom file if needed.
- **`Segmentation fault` right after `Mapchange …`:** Try **ReUnion-only** Metamod (`plugins.ini` with just **`reunion_mm_i386.so`**) to confirm AMXX or a specific **`.amxx`** plugin. Ensure the image still uses **AMXX 1.9** from the Dockerfile (`AMXX_BASE_URL`); the stock **1.8.2** in the base layer is known to crash here.
- **Server dies when a Steam client joins:** Keep **`secure 0`** in **`cstrike/config/server.cfg`**; if you re-enable **`secure 1`**, you need a full Steam dedicated / VAC setup that survives in your container.

---

## Credits

- Server base: [BLSAlin/rehlds-cstrike](https://github.com/BLSAlin/rehlds-cstrike) ([`ghcr.io/blsalin/rehlds-cstrike`](https://github.com/BLSAlin/rehlds-cstrike/pkgs/container/rehlds-cstrike))  
- Non‑Steam / mixed auth: [ReUnion](https://github.com/rehlds/ReUnion)  
- Respawn behaviour: [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS)  
