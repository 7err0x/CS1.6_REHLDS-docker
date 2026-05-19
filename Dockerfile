# Small layer on top of blsalin/rehlds-cstrike: respawn-oriented mapcycle (+ optional image/custom-maps).
# Upstream publishes to GHCR (Docker Hub name is often unavailable). Override at build time if needed.
ARG HLDS_BASE_IMAGE=ghcr.io/blsalin/rehlds-cstrike:edge

# ZM / custom maps and GameBanana-style packs are no longer baked here — use the
# `download-game-assets` compose service (see README) to populate ./data/cs16-game-assets/.

# Compile Lasermine for Biohazard (public source, pinned commit) with the same AMXX kit as runtime.
FROM debian:bookworm-slim AS lasermine-biohazard-compile
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl perl libc6-i386 zlib1g:i386 libstdc++6:i386 \
    && rm -rf /var/lib/apt/lists/*

ARG LASERMINE_GIT_SHA=7e7a285254ba699a1fcfbb43a7378bfc63acb309
ARG AMXX_BASE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.9.0.5303/amxmodx-1.9.0-git5303-base-linux.tar.gz
ARG AMXX_CSTRIKE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.9.0.5303/amxmodx-1.9.0-git5303-cstrike-linux.tar.gz

WORKDIR /amxx-kit
RUN curl -fsSL "${AMXX_BASE_URL}" | tar -xzf - \
    && curl -fsSL "${AMXX_CSTRIKE_URL}" | tar -xzf -

COPY image/zombiemod/extra-assets/addons/amxmodx/scripting/include/biohazard.inc /amxx-kit/addons/amxmodx/scripting/include/biohazard.inc

WORKDIR /amxx-kit/addons/amxmodx/scripting
RUN curl -fsSL "https://github.com/AoiKagase/Amxx-Laser-TripMine-Entity/archive/${LASERMINE_GIT_SHA}.tar.gz" | tar -xzf - \
    && srcdir="Amxx-Laser-TripMine-Entity-${LASERMINE_GIT_SHA}" \
    && cp "${srcdir}/cstrike/addons/amxmodx/scripting/lasermine.sma" . \
    && cp "${srcdir}/cstrike/addons/amxmodx/scripting/include/lasermine_zombie.inc" \
        "${srcdir}/cstrike/addons/amxmodx/scripting/include/lasermine_util.inc" \
        "${srcdir}/cstrike/addons/amxmodx/scripting/include/lasermine_const.inc" \
        "${srcdir}/cstrike/addons/amxmodx/scripting/include/lasermine.inc" \
        "${srcdir}/cstrike/addons/amxmodx/scripting/include/beams.inc" \
        include/ \
    && rm -rf "${srcdir}" \
    && sed -i 's|^// #define BIOHAZARD_SUPPORT|#define BIOHAZARD_SUPPORT|' lasermine.sma \
    && { grep -q 'register_clcmd("+dellaser"' lasermine.sma || perl -0777 -i -pe 's/(\tregister_clcmd\("say",\s*"lm_say_lasermine"\);\n)/\tregister_clcmd("+dellaser", \t"lm_progress_remove");\n\tregister_clcmd("-dellaser", \t"lm_progress_stop");\n\n$1/sm' lasermine.sma; } \
    && perl -0777 -i \
        -pe 's/stock bool:check_plugin\(\)\s*\{(?:.|\n)*?\n}/stock bool:check_plugin()\n{\n\t\/\/ ReUnion sets reu_version; upstream mistakenly treats this as non-Steam and runs amxx pause lasermine.\n\treturn false;\n}/s' \
        include/lasermine_util.inc \
    && chmod +x amxxpc \
    && ./amxxpc lasermine.sma \
    && test -f lasermine.amxx

FROM ${HLDS_BASE_IMAGE}

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY docker/cs16-merge-game-assets.sh /usr/local/sbin/cs16-merge-game-assets.sh
COPY docker/cs16-merge-game-assets-entrypoint.sh /usr/local/sbin/cs16-merge-game-assets-entrypoint.sh
RUN chmod +x /usr/local/sbin/cs16-merge-game-assets.sh /usr/local/sbin/cs16-merge-game-assets-entrypoint.sh \
    && chown steam:steam /usr/local/sbin/cs16-merge-game-assets.sh /usr/local/sbin/cs16-merge-game-assets-entrypoint.sh

COPY image/mapcycle.txt /opt/steam/hlds/cstrike/mapcycle.txt

COPY image/mapcycle.biohazard.txt /opt/steam/hlds/cstrike/mapcycle.biohazard.txt

# Optional: drop extra .bsp files here before build; they are copied last (can override names).
COPY image/custom-maps/ /tmp/custom-maps-overlay/
RUN find /tmp/custom-maps-overlay -maxdepth 1 -name '*.bsp' -exec cp -v {} /opt/steam/hlds/cstrike/maps/ \; \
    && rm -rf /tmp/custom-maps-overlay

RUN chown steam:steam /opt/steam/hlds/cstrike/mapcycle.txt \
    /opt/steam/hlds/cstrike/mapcycle.biohazard.txt \
    && find /opt/steam/hlds/cstrike/maps -user root -exec chown steam:steam {} \;

# Replace base image AMXX 1.8.2 with 1.9.x (stable on ReHLDS / ReGameDLL; 1.8.x segfaults after map load here).
# Override at build time (see docker-compose `AMXX_BASE_URL` / `AMXX_CSTRIKE_URL`; keep tarball versions aligned).
ARG AMXX_BASE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.9.0.5303/amxmodx-1.9.0-git5303-base-linux.tar.gz
ARG AMXX_CSTRIKE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.9.0.5303/amxmodx-1.9.0-git5303-cstrike-linux.tar.gz
RUN curl -fsSL -o /tmp/amxx-base.tgz "${AMXX_BASE_URL}" \
    && tar -xzf /tmp/amxx-base.tgz -C /opt/steam/hlds/cstrike \
    && rm -f /tmp/amxx-base.tgz \
    && curl -fsSL -o /tmp/amxx-cstrike.tgz "${AMXX_CSTRIKE_URL}" \
    && tar -xzf /tmp/amxx-cstrike.tgz -C /opt/steam/hlds/cstrike \
    && rm -f /tmp/amxx-cstrike.tgz \
    && chown -R steam:steam /opt/steam/hlds/cstrike/addons/amxmodx

# Leave stock modules.ini: engine/fakemeta/hamsandwich/json auto-load — enabling them explicitly causes
# duplicate Metamod loads ("already loaded") and paused plugins such as lasermine.amxx.

# Biohazard Lasermine (amxxpc-compiled upstream source with BIOHAZARD_SUPPORT; see stage lasermine-biohazard-compile).
COPY --from=lasermine-biohazard-compile /amxx-kit/addons/amxmodx/scripting/lasermine.amxx \
    /opt/steam/hlds/cstrike/addons/amxmodx/plugins/lasermine.amxx

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
