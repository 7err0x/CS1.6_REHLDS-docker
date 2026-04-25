# Small layer on top of blsalin/rehlds-cstrike: respawn-oriented mapcycle + baked community maps.
# Upstream publishes to GHCR (Docker Hub name is often unavailable). Override at build time if needed.
ARG HLDS_BASE_IMAGE=ghcr.io/blsalin/rehlds-cstrike:edge
FROM ${HLDS_BASE_IMAGE}

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY image/mapcycle.txt /opt/steam/hlds/cstrike/mapcycle.txt

# Fetch standard FY / aim / AWP maps at build time (needs `docker compose build` with network).
COPY image/scripts/bake-community-maps.sh /tmp/bake-community-maps.sh
RUN chmod +x /tmp/bake-community-maps.sh \
    && /tmp/bake-community-maps.sh \
    && rm -f /tmp/bake-community-maps.sh

# Optional: drop extra .bsp files here before build; they are copied last (can override names).
COPY image/custom-maps/ /tmp/custom-maps-overlay/
RUN find /tmp/custom-maps-overlay -maxdepth 1 -name '*.bsp' -exec cp -v {} /opt/steam/hlds/cstrike/maps/ \; \
    && rm -rf /tmp/custom-maps-overlay

RUN chown steam:steam /opt/steam/hlds/cstrike/mapcycle.txt \
    && find /opt/steam/hlds/cstrike/maps -user root -exec chown steam:steam {} \; \
    && find /opt/steam/hlds/cstrike -maxdepth 1 -name 'de_vegas.wad' -user root -exec chown steam:steam {} \;

# Replace base image AMXX 1.8.2 with 1.9.x (stable on ReHLDS / ReGameDLL; 1.8.x segfaults after map load here).
# Override at build time (see docker-compose `AMXX_BASE_URL`).
ARG AMXX_BASE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.9.0.5303/amxmodx-1.9.0-git5303-base-linux.tar.gz
RUN curl -fsSL -o /tmp/amxx-base.tgz "${AMXX_BASE_URL}" \
    && tar -xzf /tmp/amxx-base.tgz -C /opt/steam/hlds/cstrike \
    && rm -f /tmp/amxx-base.tgz \
    && chown -R steam:steam /opt/steam/hlds/cstrike/addons/amxmodx

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
    /opt/steam/hlds/cstrike/addons/amxmodx/configs/users.ini \
    /opt/steam/hlds/cstrike/reunion.cfg /opt/steam/hlds/cstrike/liblist.gam

USER steam
