# Small layer on top of blsalin/rehlds-cstrike: respawn-oriented mapcycle + baked community maps.
# Upstream publishes to GHCR (Docker Hub name is often unavailable). Override at build time if needed.
ARG HLDS_BASE_IMAGE=ghcr.io/blsalin/rehlds-cstrike:edge

# ZM map extraction must NOT run `apt` on the HLDS image: the base image pins an older glibc, but
# `apt-get upgrade` on inherited "stable" sources pulls glibc 2.41+, which then fails to load
# engine_i486.so ("cannot enable executable stack … Invalid argument"). Fetch BSPs in an isolated stage.
FROM debian:bookworm-slim AS zm-maps
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unrar-free \
    && rm -rf /var/lib/apt/lists/*
COPY image/zombiemod/hl2go-zm-urls.txt /tmp/hl2go-zm-urls.txt
COPY image/scripts/bake-zombie-night-maps.sh /tmp/bake-zombie-night-maps.sh
ENV MAPS_DIR=/zm-maps-out \
    ZM_MAPS_URL_FILE=/tmp/hl2go-zm-urls.txt
RUN mkdir -p /zm-maps-out \
    && chmod +x /tmp/bake-zombie-night-maps.sh \
    && /tmp/bake-zombie-night-maps.sh \
    && rm -f /tmp/bake-zombie-night-maps.sh /tmp/hl2go-zm-urls.txt

FROM ${HLDS_BASE_IMAGE}

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY image/mapcycle.txt /opt/steam/hlds/cstrike/mapcycle.txt

# Fetch standard FY / aim / AWP maps at build time (needs `docker compose build` with network).
COPY image/scripts/bake-community-maps.sh /tmp/bake-community-maps.sh
RUN chmod +x /tmp/bake-community-maps.sh \
    && /tmp/bake-community-maps.sh \
    && rm -f /tmp/bake-community-maps.sh

# Popular dark ZM maps (HL2GO RAR → BSP); built in stage `zm-maps` so runtime glibc stays compatible.
COPY --from=zm-maps /zm-maps-out/ /opt/steam/hlds/cstrike/maps/

COPY image/mapcycle.biohazard.txt /opt/steam/hlds/cstrike/mapcycle.biohazard.txt

# Optional: drop extra .bsp files here before build; they are copied last (can override names).
COPY image/custom-maps/ /tmp/custom-maps-overlay/
RUN find /tmp/custom-maps-overlay -maxdepth 1 -name '*.bsp' -exec cp -v {} /opt/steam/hlds/cstrike/maps/ \; \
    && rm -rf /tmp/custom-maps-overlay

RUN chown steam:steam /opt/steam/hlds/cstrike/mapcycle.txt \
    /opt/steam/hlds/cstrike/mapcycle.biohazard.txt \
    && find /opt/steam/hlds/cstrike/maps -user root -exec chown steam:steam {} \; \
    && find /opt/steam/hlds/cstrike -maxdepth 1 -name 'de_vegas.wad' -user root -exec chown steam:steam {} \;

# Replace base image AMXX 1.8.2 with 1.9.x (stable on ReHLDS / ReGameDLL; 1.8.x segfaults after map load here).
# Override at build time (see docker-compose `AMXX_BASE_URL`).
ARG AMXX_BASE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.9.0.5303/amxmodx-1.9.0-git5303-base-linux.tar.gz
RUN curl -fsSL -o /tmp/amxx-base.tgz "${AMXX_BASE_URL}" \
    && tar -xzf /tmp/amxx-base.tgz -C /opt/steam/hlds/cstrike \
    && rm -f /tmp/amxx-base.tgz \
    && chown -R steam:steam /opt/steam/hlds/cstrike/addons/amxmodx

# After AMXX tarball: optional biohazard.amxx from image/zombiemod/extra-plugins/ + alternate plugins list.
COPY image/zombiemod/extra-plugins/ /tmp/zombie-extra/
RUN bash -c 'shopt -s nullglob; for f in /tmp/zombie-extra/*.amxx; do cp -v "$f" /opt/steam/hlds/cstrike/addons/amxmodx/plugins/; done' \
    && rm -rf /tmp/zombie-extra

COPY image/zombiemod/plugins-biohazard.ini /opt/steam/hlds/cstrike/addons/amxmodx/configs/plugins-biohazard.ini

# Optional: merge full mod pack (models/, sound/, addons/...) — see image/zombiemod/extra-assets/README.txt
COPY image/zombiemod/extra-assets/ /tmp/zombie-assets/
RUN bash -c 'shopt -s nullglob; for p in /tmp/zombie-assets/*; do \
      b=$(basename "$p"); \
      [[ "$b" == README.txt || "$b" == .gitkeep ]] && continue; \
      cp -a "$p" /opt/steam/hlds/cstrike/; \
    done' \
    && rm -rf /tmp/zombie-assets

# ReUnion: non-Steam / mixed clients need auth emulation (load before AMXX per ReUnion docs).
ARG REUNION_VERSION=0.2.0.25
RUN curl -fsSL -o /tmp/reunion.zip "https://github.com/rehlds/ReUnion/releases/download/${REUNION_VERSION}/reunion-${REUNION_VERSION}.zip" \
    && unzip -qo /tmp/reunion.zip -d /tmp/reunion \
    && install -d /opt/steam/hlds/cstrike/addons/reunion \
    && cp -v /tmp/reunion/bin/Linux/reunion_mm_i386.so /opt/steam/hlds/cstrike/addons/reunion/ \
    && cp -v /tmp/reunion/reunion.cfg /opt/steam/hlds/cstrike/reunion.cfg \
    && rm -rf /tmp/reunion /tmp/reunion.zip

# Metamod: ReUnion first, then AMXX (order matters for mixed Steam / non-Steam).
RUN printf '%s\n%s\n' \
    'linux addons/reunion/reunion_mm_i386.so' \
    'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' \
    > /opt/steam/hlds/cstrike/addons/metamod/plugins.ini

# AMXX admins (defaults: stock plugins.ini + modules.ini from the 1.9 base tarball).
COPY cstrike/amxmodx/users.ini /opt/steam/hlds/cstrike/addons/amxmodx/configs/users.ini

# VAC off in liblist; ReGameDLL still loads via Metamod → cs.so chain.
RUN sed -i 's/^secure "1"/secure "0"/' /opt/steam/hlds/cstrike/liblist.gam

# AuthVersion 2 allows empty SteamIdHashSalt; accept p47/p48 no-steam without "Steam validation rejected" (cid 5 = reject).
RUN sed -i \
    -e 's/^AuthVersion = 3/AuthVersion = 2/' \
    -e 's/^cid_NoSteam47 = 5/cid_NoSteam47 = 3/' \
    -e 's/^cid_NoSteam48 = 5/cid_NoSteam48 = 3/' \
    /opt/steam/hlds/cstrike/reunion.cfg

RUN chown -R steam:steam /opt/steam/hlds/cstrike/addons/reunion \
    /opt/steam/hlds/cstrike/addons/metamod/plugins.ini \
    /opt/steam/hlds/cstrike/addons/amxmodx/plugins \
    /opt/steam/hlds/cstrike/addons/amxmodx/configs \
    /opt/steam/hlds/cstrike/addons/amxmodx/data \
    /opt/steam/hlds/cstrike/reunion.cfg /opt/steam/hlds/cstrike/liblist.gam \
    && { chown -R steam:steam /opt/steam/hlds/cstrike/models 2>/dev/null || true; } \
    && { chown -R steam:steam /opt/steam/hlds/cstrike/sound 2>/dev/null || true; }

USER steam
