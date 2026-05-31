# Multi-stage CS 1.6 image: HLDS + ReHLDS stack (vendored from BLSAlin/rehlds-cstrike recipe),
# AMXX 1.9, ReUnion, Biohazard extras. First build downloads HLDS via SteamCMD (needs network).
#
# Upstream reference: https://github.com/BLSAlin/rehlds-cstrike/blob/master/Dockerfile

# -----------------------------------------------------------------------------
# Stage 1 — AMXX kit + compile all Biohazard-pack .sma (incl. lasermine)
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS amxx-build

ARG LASERMINE_GIT_SHA=7e7a285254ba699a1fcfbb43a7378bfc63acb309
ARG AMXX_BASE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.9.0.5303/amxmodx-1.9.0-git5303-base-linux.tar.gz
ARG AMXX_CSTRIKE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.9.0.5303/amxmodx-1.9.0-git5303-cstrike-linux.tar.gz

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl perl libc6-i386 zlib1g:i386 libstdc++6:i386 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /amxx-kit
RUN curl -fsSL "${AMXX_BASE_URL}" | tar -xzf - \
    && curl -fsSL "${AMXX_CSTRIKE_URL}" | tar -xzf -

WORKDIR /amxx-kit/addons/amxmodx/scripting

COPY image/zombiemod/extra-assets/addons/amxmodx/scripting/*.sma ./
COPY image/zombiemod/extra-assets/addons/amxmodx/scripting/*.cfg ./
COPY image/zombiemod/extra-assets/addons/amxmodx/scripting/include/ ./include/

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
        include/lasermine_util.inc

COPY docker/amxx-compile-all.sh /usr/local/bin/amxx-compile-all.sh
RUN chmod +x /usr/local/bin/amxx-compile-all.sh \
    && /usr/local/bin/amxx-compile-all.sh

# -----------------------------------------------------------------------------
# Stage 2 — HLDS + ReHLDS + Metamod + ReGameDLL + ReAPI (no AMXX 1.8 — runtime uses 1.9)
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS hlds-base

ARG REHLDS_BUILD=3.15.0.896
ARG METAMOD_VERSION=1.3.0.149
ARG REGAMEDLL_VERSION=5.30.0.814
ARG REAPI_VERSION=5.29.0.358
ARG STEAMCMD_URL=https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
ARG REHLDS_URL="https://github.com/rehlds/ReHLDS/releases/download/${REHLDS_BUILD}/rehlds-bin-${REHLDS_BUILD}.zip"
ARG METAMOD_URL="https://github.com/rehlds/Metamod-R/releases/download/${METAMOD_VERSION}/metamod-bin-${METAMOD_VERSION}.zip"
ARG REGAMEDLL_URL="https://github.com/rehlds/ReGameDLL_CS/releases/download/${REGAMEDLL_VERSION}/regamedll-bin-${REGAMEDLL_VERSION}.zip"
ARG REAPI_URL="https://github.com/rehlds/ReAPI/releases/download/${REAPI_VERSION}/reapi-bin-${REAPI_VERSION}.zip"

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV CPU_MHZ=2300

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends locales \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen en_US.UTF-8

RUN groupadd -r steam \
    && useradd -r -g steam -m -d /opt/steam steam

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
        xz-utils \
        zip \
        libc6-i386 \
        lib32gcc-s1 \
    && rm -rf /var/lib/apt/lists/*

USER steam
WORKDIR /opt/steam

COPY --chown=steam:steam lib/hlds.install /opt/steam/hlds.install

RUN curl -fsSL "${STEAMCMD_URL}" | tar -xzf - \
    && ./steamcmd.sh +runscript hlds.install

RUN curl -fsSL -o "/tmp/rehlds-bin-${REHLDS_BUILD}.zip" "${REHLDS_URL}" \
    && unzip -o -j "/tmp/rehlds-bin-${REHLDS_BUILD}.zip" "bin/linux32/*" -d "/opt/steam/hlds" \
    && unzip -o -j "/tmp/rehlds-bin-${REHLDS_BUILD}.zip" "bin/linux32/valve/*" -d "/opt/steam/hlds" \
    && rm -f "/tmp/rehlds-bin-${REHLDS_BUILD}.zip"

RUN mkdir -p "${HOME}/.steam" \
    && ln -sf /opt/steam/linux32 "${HOME}/.steam/sdk32"

RUN touch /opt/steam/hlds/cstrike/listip.cfg /opt/steam/hlds/cstrike/banned.cfg

RUN mkdir -p /opt/steam/hlds/cstrike/addons/metamod \
    && : > /opt/steam/hlds/cstrike/addons/metamod/plugins.ini

RUN curl -fsSL -o /tmp/metamod.zip "${METAMOD_URL}" \
    && unzip -o -j /tmp/metamod.zip "addons/metamod/metamod*" -d /opt/steam/hlds/cstrike/addons/metamod \
    && chmod -R a+rX /opt/steam/hlds/cstrike/addons/metamod \
    && rm -f /tmp/metamod.zip

RUN sed -i 's|dlls/cs\.so|addons/metamod/metamod_i386.so|g' /opt/steam/hlds/cstrike/liblist.gam

RUN curl -fsSL -o "/tmp/regamedll-bin-${REGAMEDLL_VERSION}.zip" "${REGAMEDLL_URL}" \
    && unzip -o -j "/tmp/regamedll-bin-${REGAMEDLL_VERSION}.zip" "bin/linux32/cstrike/*" -d "/opt/steam/hlds/cstrike" \
    && unzip -o -j "/tmp/regamedll-bin-${REGAMEDLL_VERSION}.zip" "bin/linux32/cstrike/dlls/*" -d "/opt/steam/hlds/cstrike/dlls" \
    && rm -f "/tmp/regamedll-bin-${REGAMEDLL_VERSION}.zip"

RUN curl -fsSL -o "/tmp/reapi-bin-${REAPI_VERSION}.zip" "${REAPI_URL}" \
    && unzip -o "/tmp/reapi-bin-${REAPI_VERSION}.zip" -d "/opt/steam/hlds/cstrike" \
    && rm -f "/tmp/reapi-bin-${REAPI_VERSION}.zip"

WORKDIR /opt/steam/hlds
RUN chmod +x hlds_run hlds_linux \
    && echo 10 > steam_appid.txt

# -----------------------------------------------------------------------------
# Stage 3 — cs16-respawn: mapcycles, AMXX 1.9, ReUnion, Biohazard pack
# -----------------------------------------------------------------------------
FROM hlds-base AS cs16

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY docker/cs16-merge-game-assets.sh /usr/local/sbin/cs16-merge-game-assets.sh
COPY docker/cs16-merge-game-assets-entrypoint.sh /usr/local/sbin/cs16-merge-game-assets-entrypoint.sh
RUN chmod +x /usr/local/sbin/cs16-merge-game-assets.sh /usr/local/sbin/cs16-merge-game-assets-entrypoint.sh \
    && chown steam:steam /usr/local/sbin/cs16-merge-game-assets.sh /usr/local/sbin/cs16-merge-game-assets-entrypoint.sh

COPY image/mapcycle.txt /opt/steam/hlds/cstrike/mapcycle.txt
COPY image/mapcycle.biohazard.txt /opt/steam/hlds/cstrike/mapcycle.biohazard.txt

COPY image/custom-maps/ /tmp/custom-maps-overlay/
RUN find /tmp/custom-maps-overlay -maxdepth 1 -name '*.bsp' -exec cp -v {} /opt/steam/hlds/cstrike/maps/ \; \
    && rm -rf /tmp/custom-maps-overlay

RUN chown steam:steam /opt/steam/hlds/cstrike/mapcycle.txt \
    /opt/steam/hlds/cstrike/mapcycle.biohazard.txt \
    && find /opt/steam/hlds/cstrike/maps -user root -exec chown steam:steam {} \;

ARG AMXX_BASE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.9.0.5303/amxmodx-1.9.0-git5303-base-linux.tar.gz
ARG AMXX_CSTRIKE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.9.0.5303/amxmodx-1.9.0-git5303-cstrike-linux.tar.gz

RUN curl -fsSL -o /tmp/amxx-base.tgz "${AMXX_BASE_URL}" \
    && tar -xzf /tmp/amxx-base.tgz -C /opt/steam/hlds/cstrike \
    && rm -f /tmp/amxx-base.tgz \
    && curl -fsSL -o /tmp/amxx-cstrike.tgz "${AMXX_CSTRIKE_URL}" \
    && tar -xzf /tmp/amxx-cstrike.tgz -C /opt/steam/hlds/cstrike \
    && rm -f /tmp/amxx-cstrike.tgz \
    && if [[ -d /opt/steam/hlds/cstrike/addons/reapi ]]; then \
         grep -qFx 'reapi' /opt/steam/hlds/cstrike/addons/amxmodx/configs/modules.ini \
           || echo 'reapi' >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/modules.ini; \
       fi \
    && chown -R steam:steam /opt/steam/hlds/cstrike/addons/amxmodx

# Optional pre-built overrides (skipped when empty); fresh compiles below replace same filenames.
COPY image/zombiemod/extra-plugins/ /tmp/zombie-extra/
RUN bash -c 'shopt -s nullglob; for f in /tmp/zombie-extra/*.amxx; do cp -v "$f" /opt/steam/hlds/cstrike/addons/amxmodx/plugins/; done' \
    && rm -rf /tmp/zombie-extra

COPY --from=amxx-build /amxx-kit/addons/amxmodx/scripting/*.amxx \
    /opt/steam/hlds/cstrike/addons/amxmodx/plugins/

COPY image/zombiemod/plugins-biohazard.ini /opt/steam/hlds/cstrike/addons/amxmodx/configs/plugins-biohazard.ini

COPY image/zombiemod/extra-assets/ /tmp/zombie-assets/
RUN bash -c 'shopt -s nullglob; for p in /tmp/zombie-assets/*; do \
      b=$(basename "$p"); \
      [[ "$b" == README.txt || "$b" == .gitkeep ]] && continue; \
      cp -a "$p" /opt/steam/hlds/cstrike/; \
    done' \
    && rm -rf /tmp/zombie-assets

ARG REUNION_VERSION=0.2.0.25
RUN curl -fsSL -o /tmp/reunion.zip "https://github.com/rehlds/ReUnion/releases/download/${REUNION_VERSION}/reunion-${REUNION_VERSION}.zip" \
    && unzip -qo /tmp/reunion.zip -d /tmp/reunion \
    && install -d /opt/steam/hlds/cstrike/addons/reunion \
    && cp -v /tmp/reunion/bin/Linux/reunion_mm_i386.so /opt/steam/hlds/cstrike/addons/reunion/ \
    && cp -v /tmp/reunion/reunion.cfg /opt/steam/hlds/cstrike/reunion.cfg \
    && rm -rf /tmp/reunion /tmp/reunion.zip

RUN printf '%s\n%s\n' \
    'linux addons/reunion/reunion_mm_i386.so' \
    'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' \
    > /opt/steam/hlds/cstrike/addons/metamod/plugins.ini

COPY cstrike/amxmodx/users.ini /opt/steam/hlds/cstrike/addons/amxmodx/configs/users.ini

RUN sed -i 's/^secure "1"/secure "0"/' /opt/steam/hlds/cstrike/liblist.gam \
    && sed -i \
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
WORKDIR /opt/steam/hlds

EXPOSE 27015/tcp 27015/udp
