# syntax=docker/dockerfile:1.4
# Serves a GoldSrc-style tree (maps/, sound/, …): cs16-bootstrap (baked assets) + cstrike gfx/resource + game-assets at runtime.
ARG GAME_IMAGE=ghcr.io/7err0x/cs16-biohazard:latest
FROM ${GAME_IMAGE} AS game

FROM nginx:alpine
RUN apk add --no-cache bzip2
COPY docker/fastdl/default.conf /etc/nginx/conf.d/default.conf
COPY docker/fastdl/compress-bz2.sh /usr/local/bin/compress-bz2.sh
RUN chmod +x /usr/local/bin/compress-bz2.sh

SHELL ["/bin/sh", "-exc"]
RUN mkdir -p /built/maps /built/sound /built/models /built/sprites /built/gfx /built/resource /built/overviews
RUN --mount=type=bind,from=game,source=/usr/local/share/cs16-bootstrap,target=/bootstrap \
    --mount=type=bind,from=game,source=/opt/steam/hlds/cstrike,target=/cs \
    for d in maps sound models sprites; do \
      if [ -d "/bootstrap/$d" ]; then cp -a "/bootstrap/$d/." "/built/$d/"; fi; \
    done \
    && for d in gfx resource overviews; do \
      if [ -d "/cs/$d" ]; then cp -a "/cs/$d/." "/built/$d/"; fi; \
    done \
    && if [ -d "/bootstrap/wads" ]; then \
         for w in /bootstrap/wads/*.wad /bootstrap/wads/*.WAD; do \
           [ -f "$w" ] || continue; cp -a "$w" /built/; \
         done; \
       fi \
    && for f in /cs/*.wad; do \
         [ -f "$f" ] || continue; cp -a "$f" /built/; \
       done
RUN --mount=type=bind,from=game,source=/opt/steam/hlds/valve/models,target=/valve \
    for f in glassgibs.mdl w_flare.mdl; do \
      if [ -f "/valve/$f" ]; then cp -a "/valve/$f" "/built/models/"; fi; \
    done \
    && /usr/local/bin/compress-bz2.sh /built

COPY docker/fastdl/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
