# Multi-stage CS 1.6 image: HLDS + ReHLDS stack (vendored from BLSAlin/rehlds-cstrike recipe),
# AMXX 1.9, ReUnion, Biohazard extras. First build downloads HLDS via SteamCMD (needs network).
#
# Upstream reference: https://github.com/BLSAlin/rehlds-cstrike/blob/master/Dockerfile

# -----------------------------------------------------------------------------
# Stage 1 — AMXX kit + compile all Biohazard-pack .sma (incl. lasermine)
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS amxx-build

ARG AMXX_BASE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.10.0.5476/amxmodx-1.10.0-git5476-base-linux.tar.gz
ARG AMXX_CSTRIKE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.10.0.5476/amxmodx-1.10.0-git5476-cstrike-linux.tar.gz

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

COPY vendor/Amxx-Laser-TripMine-Entity/cstrike/addons/amxmodx/scripting/lasermine.sma ./
COPY vendor/Amxx-Laser-TripMine-Entity/cstrike/addons/amxmodx/scripting/include/lasermine_zombie.inc \
	vendor/Amxx-Laser-TripMine-Entity/cstrike/addons/amxmodx/scripting/include/lasermine_util.inc \
	vendor/Amxx-Laser-TripMine-Entity/cstrike/addons/amxmodx/scripting/include/lasermine_const.inc \
	vendor/Amxx-Laser-TripMine-Entity/cstrike/addons/amxmodx/scripting/include/lasermine.inc \
	vendor/Amxx-Laser-TripMine-Entity/cstrike/addons/amxmodx/scripting/include/beams.inc \
	./include/

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

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV CPU_MHZ=3200

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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

RUN touch /opt/steam/hlds/cstrike/listip.cfg /opt/steam/hlds/cstrike/banned.cfg \
    /opt/steam/hlds/cstrike/config.cfg

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
# Stage 3 — cs16 build: mapcycles, AMXX 1.9, ReUnion, Biohazard pack, then slim
# -----------------------------------------------------------------------------
FROM hlds-base AS cs16-build

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY docker/cs16-state-init.sh /usr/local/sbin/cs16-state-init.sh
COPY docker/cs16-entrypoint.sh /usr/local/sbin/cs16-entrypoint.sh
COPY docker/cs16-image-slim.sh /usr/local/sbin/cs16-image-slim.sh
COPY docker/ebot-waypoints-bake.sh /usr/local/sbin/ebot-waypoints-bake.sh
RUN chmod +x /usr/local/sbin/cs16-state-init.sh /usr/local/sbin/cs16-entrypoint.sh /usr/local/sbin/cs16-image-slim.sh \
    /usr/local/sbin/ebot-waypoints-bake.sh

COPY image/mapcycle.txt /opt/steam/hlds/cstrike/mapcycle.txt
COPY image/mapcycle.biohazard.txt /opt/steam/hlds/cstrike/mapcycle.biohazard.txt

COPY image/custom-maps/ /tmp/custom-maps-overlay/
RUN find /tmp/custom-maps-overlay -maxdepth 1 -name '*.bsp' -exec cp -v {} /opt/steam/hlds/cstrike/maps/ \; \
    && rm -rf /tmp/custom-maps-overlay

RUN chown -R steam:steam /opt/steam/hlds/cstrike/mapcycle.txt \
    /opt/steam/hlds/cstrike/mapcycle.biohazard.txt \
    /opt/steam/hlds/cstrike/maps

ARG AMXX_BASE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.10.0.5476/amxmodx-1.10.0-git5476-base-linux.tar.gz
ARG AMXX_CSTRIKE_URL=https://github.com/alliedmodders/amxmodx/releases/download/1.10.0.5476/amxmodx-1.10.0-git5476-cstrike-linux.tar.gz

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

COPY image/zombiemod/extra-plugins/ /tmp/zombie-extra/
RUN bash -c 'shopt -s nullglob; for f in /tmp/zombie-extra/*.amxx; do cp -v "$f" /opt/steam/hlds/cstrike/addons/amxmodx/plugins/; done' \
    && rm -rf /tmp/zombie-extra

COPY --from=amxx-build /amxx-kit/addons/amxmodx/scripting/*.amxx \
    /opt/steam/hlds/cstrike/addons/amxmodx/plugins/

# Profile lists live under profiles/ — AMXX auto-loads every configs/plugins-*.ini (not only plugins.ini).
COPY image/zombiemod/plugins-biohazard.ini /opt/steam/hlds/cstrike/addons/amxmodx/configs/profiles/plugins-biohazard.ini
COPY image/zombiemod/plugins-respawn.ini /opt/steam/hlds/cstrike/addons/amxmodx/configs/profiles/plugins-respawn.ini
COPY image/zombiemod/maps-biohazard.ini /opt/steam/hlds/cstrike/addons/amxmodx/configs/profiles/maps-biohazard.ini

COPY image/zombiemod/extra-assets/ /tmp/zombie-assets/
RUN bash -c 'shopt -s nullglob; for p in /tmp/zombie-assets/*; do \
      b=$(basename "$p"); \
      [[ "$b" == README.txt || "$b" == .gitkeep ]] && continue; \
      cp -a "$p" /opt/steam/hlds/cstrike/; \
    done' \
    && rm -rf /tmp/zombie-assets

ARG REUNION_VERSION=0.2.0.25
ARG EBOT_VERSION=1.10
ARG EBOT_URL="https://github.com/EfeDursun125/CS-EBOT/releases/download/${EBOT_VERSION}/E-BOT.${EBOT_VERSION}.Beta.zip"

RUN curl -fsSL -o /tmp/reunion.zip "https://github.com/rehlds/ReUnion/releases/download/${REUNION_VERSION}/reunion-${REUNION_VERSION}.zip" \
    && unzip -qo /tmp/reunion.zip -d /tmp/reunion \
    && install -d /opt/steam/hlds/cstrike/addons/reunion \
    && cp -v /tmp/reunion/bin/Linux/reunion_mm_i386.so /opt/steam/hlds/cstrike/addons/reunion/ \
    && cp -v /tmp/reunion/reunion.cfg /opt/steam/hlds/cstrike/reunion.cfg \
    && rm -rf /tmp/reunion /tmp/reunion.zip

ARG CS16_PLUGINS_INI=
COPY cstrike/ebot/ebot-biohazard.cfg /tmp/ebot-biohazard.cfg
COPY cstrike/ebot/ebot-waypoints-bake.cfg /tmp/ebot-waypoints-bake.cfg
COPY cstrike/ebot/names.cfg /tmp/ebot-names.cfg
RUN if [[ "${CS16_PLUGINS_INI}" == "plugins-biohazard.ini" ]]; then \
      curl -fsSL -o /tmp/ebot.zip "${EBOT_URL}" \
      && unzip -qo /tmp/ebot.zip -d /opt/steam/hlds/cstrike/addons/ \
      && cp /tmp/ebot-biohazard.cfg /opt/steam/hlds/cstrike/addons/ebot/ebot-biohazard.cfg \
      && cp /tmp/ebot-waypoints-bake.cfg /opt/steam/hlds/cstrike/addons/ebot/ebot-waypoints-bake.cfg \
      && cp /tmp/ebot-names.cfg /opt/steam/hlds/cstrike/addons/ebot/names.cfg \
      && rm -f /tmp/ebot.zip /tmp/ebot-biohazard.cfg /tmp/ebot-waypoints-bake.cfg /tmp/ebot-names.cfg \
      && chmod -R a+rX /opt/steam/hlds/cstrike/addons/ebot; \
    else \
      rm -f /tmp/ebot-biohazard.cfg /tmp/ebot-waypoints-bake.cfg /tmp/ebot-names.cfg; \
    fi

RUN if [[ "${CS16_PLUGINS_INI}" == "plugins-biohazard.ini" ]]; then \
      printf '%s\n%s\n%s\n' \
        'linux addons/reunion/reunion_mm_i386.so' \
        'linux addons/ebot/dlls/ebot.so' \
        'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' \
        > /opt/steam/hlds/cstrike/addons/metamod/plugins.ini; \
    else \
      printf '%s\n%s\n' \
        'linux addons/reunion/reunion_mm_i386.so' \
        'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' \
        > /opt/steam/hlds/cstrike/addons/metamod/plugins.ini; \
    fi

COPY cstrike/amxmodx/users.ini /opt/steam/hlds/cstrike/addons/amxmodx/configs/users.ini
COPY cstrike/server.cfg /opt/steam/hlds/cstrike/server.cfg
COPY cstrike/config/ /opt/steam/hlds/cstrike/config/
COPY cstrike/reunion.cfg /opt/steam/hlds/cstrike/reunion.cfg

ARG CS16_SERVER_CONFIG=server.cfg
ARG CS16_PLUGINS_INI=
ARG CS16_MAPS_INI=
RUN if [[ "$CS16_SERVER_CONFIG" != "server.cfg" ]]; then \
      cp "/opt/steam/hlds/cstrike/config/${CS16_SERVER_CONFIG}" \
         /opt/steam/hlds/cstrike/config/server.cfg; \
    fi \
    && rm -f /opt/steam/hlds/cstrike/addons/amxmodx/configs/plugins-*.ini \
    && if [[ -n "$CS16_PLUGINS_INI" \
      && -f "/opt/steam/hlds/cstrike/addons/amxmodx/configs/profiles/${CS16_PLUGINS_INI}" ]]; then \
      cp "/opt/steam/hlds/cstrike/addons/amxmodx/configs/profiles/${CS16_PLUGINS_INI}" \
         /opt/steam/hlds/cstrike/addons/amxmodx/configs/plugins.ini; \
    fi \
    && rm -f /opt/steam/hlds/cstrike/addons/amxmodx/configs/maps-*.ini \
    && if [[ -n "$CS16_MAPS_INI" \
      && -f "/opt/steam/hlds/cstrike/addons/amxmodx/configs/profiles/${CS16_MAPS_INI}" ]]; then \
      cp "/opt/steam/hlds/cstrike/addons/amxmodx/configs/profiles/${CS16_MAPS_INI}" \
         /opt/steam/hlds/cstrike/addons/amxmodx/configs/maps.ini; \
    fi \
    && if [[ "$CS16_PLUGINS_INI" == "plugins-biohazard.ini" ]]; then \
      MOTD_CFG="/opt/steam/hlds/cstrike/addons/amxmodx/configs/biohazard_motd_en.html"; \
      SMA="/opt/steam/hlds/cstrike/addons/amxmodx/scripting/biohazard.sma"; \
      VERSION=$(grep -m1 '^#define VERSION' "$SMA" | sed 's/.*"\([^"]*\)".*/\1/'); \
      cp "$MOTD_CFG" /opt/steam/hlds/cstrike/motd.txt; \
      sed -i "s/#Version#/${VERSION}/g" /opt/steam/hlds/cstrike/motd.txt; \
    elif [[ "$CS16_PLUGINS_INI" == "plugins-respawn.ini" ]]; then \
      MOTD_CFG="/opt/steam/hlds/cstrike/addons/amxmodx/configs/respawn_motd_en.html"; \
      SMA="/opt/steam/hlds/cstrike/addons/amxmodx/scripting/biohazard.sma"; \
      VERSION=$(grep -m1 '^#define VERSION' "$SMA" | sed 's/.*"\([^"]*\)".*/\1/'); \
      cp "$MOTD_CFG" /opt/steam/hlds/cstrike/motd.txt; \
      sed -i "s/#Version#/${VERSION}/g" /opt/steam/hlds/cstrike/motd.txt; \
    fi

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
    /opt/steam/hlds/cstrike/motd.txt \
    && { chown -R steam:steam /opt/steam/hlds/cstrike/addons/ebot 2>/dev/null || true; } \
    && { chown -R steam:steam /opt/steam/hlds/cstrike/models 2>/dev/null || true; } \
    && { chown -R steam:steam /opt/steam/hlds/cstrike/sound 2>/dev/null || true; }

RUN if [[ "$CS16_PLUGINS_INI" == "plugins-biohazard.ini" ]]; then \
      export CS16_STATE_PROFILE=biohazard; \
    else \
      export CS16_STATE_PROFILE=respawn; \
    fi \
    && /usr/local/sbin/cs16-image-slim.sh \
    && chown -hR steam:steam /usr/local/share/cs16-bootstrap /opt/steam

# -----------------------------------------------------------------------------
# Stage 4 — runtime: i386 libs only (no curl/unzip build tools)
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS cs16

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV CPU_MHZ=2300

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN groupadd -r steam \
    && useradd -r -g steam -m -d /opt/steam steam

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        libc6-i386 \
        lib32gcc-s1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=cs16-build --chown=steam:steam /opt/steam /opt/steam
COPY --from=cs16-build --chown=steam:steam /usr/local/sbin/cs16-state-init.sh /usr/local/sbin/cs16-state-init.sh
COPY --from=cs16-build --chown=steam:steam /usr/local/sbin/cs16-entrypoint.sh /usr/local/sbin/cs16-entrypoint.sh
COPY --from=cs16-build --chown=steam:steam /usr/local/sbin/ebot-waypoints-bake.sh /usr/local/sbin/ebot-waypoints-bake.sh
COPY --from=cs16-build --chown=steam:steam /usr/local/share/cs16-bootstrap /usr/local/share/cs16-bootstrap

USER steam
WORKDIR /opt/steam/hlds

EXPOSE 27015/tcp 27015/udp
