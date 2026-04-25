# Counter-Strike 1.6 in Docker (respawn / deathmatch mode)

This stack runs a **Counter-Strike 1.6** dedicated server using a **small custom image** built `FROM` the upstream [rehlds-cstrike](https://github.com/BLSAlin/rehlds-cstrike) container (default **`ghcr.io/blsalin/rehlds-cstrike:edge`** — see [GHCR package](https://github.com/BLSAlin/rehlds-cstrike/pkgs/container/rehlds-cstrike)). The **Dockerfile** installs **[ReUnion](https://github.com/rehlds/ReUnion)** and configures **Metamod-r** to load **only** `reunion_mm_i386.so` (no **AMXX** — loading `amxmodx_mm` still **segfaults on map load** in Docker here). **ReGameDLL** stays active for **respawn** (`mp_forcerespawn` in `cstrike/config/server.cfg`). **`liblist.gam`** keeps **`secure "0"`** and **`cstrike/config/server.cfg`** sets **`secure 0`** so **VAC is off** for broad client compatibility (Steam + typical non‑Steam builds). The image bakes a **respawn-oriented mapcycle** and **community FY / aim / AWP maps**.

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

3. In CS 1.6, open the console (`~`) and connect (replace host and port if needed):

   ```text
   connect 127.0.0.1:27015
   ```

4. Watch logs:

   ```bash
   docker compose logs -f
   ```

---

## Configuration

| Item | Purpose |
|------|--------|
| `.env` | Port, slots, **RCON password**, start map, hostname (see `.env.example`). |
| `cstrike/config/server.cfg` | Gameplay: **respawn**, teams vs FFA, round time, etc. Also **`secure 0`** / **`mp_consistency 0`** (VAC off; complements **`liblist.gam`**). |
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
| [`Dockerfile`](Dockerfile) | Bakes maps/WADs, installs **[ReUnion](https://github.com/rehlds/ReUnion)** (`ARG REUNION_VERSION`), **`plugins.ini`** = ReUnion only, **`secure "0"`** in **`liblist.gam`**, patches **`reunion.cfg`** for mixed Steam / no‑Steam clients. |
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

The container is named **`cs16-respawn`** (`container_name` in Compose). One-off shell as the steam user (for debugging):

```bash
docker exec -it cs16-respawn bash
```

Game files live under `/opt/steam/hlds/cstrike` inside the container.

---

## RCON (remote console)

Set **`RCON_PASSWORD`** in `.env` before going live. From the **game client** console (with RCON tools / supported client), or from **HLDS-style** tooling, you send commands prefixed with your RCON password. Typical workflow: use an RCON client, or bind scripts, pointed at **`host:SERVER_PORT`** with the same password as **`RCON_PASSWORD`**.

Useful **server variables** (set in `cstrike/config/server.cfg` or via RCON if your client supports `rcon <password> <command>`):

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

Exact **client-side** RCON syntax depends on your client/mod; many admins use **HLSW** or **Steam** server tools.

---

## Metamod, ReUnion, and AMX Mod X

- **Metamod-r** is loaded from **`liblist.gam`** as upstream intended.
- **ReUnion** is the **only** Metamod plugin in **`addons/metamod/plugins.ini`**. It bridges **protocol 47/48** and **non‑Steam** clients to ReHLDS.
- **AMXX** files remain under **`addons/amxmodx/`** but **are not loaded** — enabling **`linux addons/amxmodx/dlls/amxmodx_mm_i386.so`** in **`plugins.ini`** still triggers a **map-load segfault** in Docker on this stack. To use AMXX you would need a different image layout or versions (out of scope here).

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
- **`Segmentation fault` right after `Mapchange …` with AMXX:** Do **not** add **`amxmodx_mm_i386.so`** to **`plugins.ini`** on this Docker setup — use **ReUnion only**. If you need AMXX, use another base or debug versions yourself.
- **Server dies when a Steam client joins:** Keep **`secure 0`** in **`cstrike/config/server.cfg`**; if you re-enable **`secure 1`**, you need a full Steam dedicated / VAC setup that survives in your container.

---

## Credits

- Server base: [BLSAlin/rehlds-cstrike](https://github.com/BLSAlin/rehlds-cstrike) ([`ghcr.io/blsalin/rehlds-cstrike`](https://github.com/BLSAlin/rehlds-cstrike/pkgs/container/rehlds-cstrike))  
- Non‑Steam / mixed auth: [ReUnion](https://github.com/rehlds/ReUnion)  
- Respawn behaviour: [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS)  
