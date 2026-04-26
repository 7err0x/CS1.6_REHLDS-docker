# syntax=docker/dockerfile:1.4
# Serves maps / models / sound / … already baked into the game image (same tag as GAME_IMAGE).
# Build after the game image: docker compose build cs16 fastdl
ARG GAME_IMAGE=cs16-respawn:latest
FROM ${GAME_IMAGE} AS game

FROM nginx:alpine
COPY docker/fastdl/default.conf /etc/nginx/conf.d/default.conf
SHELL ["/bin/sh", "-exc"]
RUN --mount=type=bind,from=game,source=/opt/steam/hlds/cstrike,target=/cs \
    mkdir -p /usr/share/nginx/html \
    && test -d /cs/maps \
    && cp -a /cs/maps /usr/share/nginx/html/ \
    && for d in models sound sprites gfx resource overviews; do \
         if [ -d "/cs/$d" ]; then cp -a "/cs/$d" /usr/share/nginx/html/; fi; \
       done \
    && for f in /cs/*.wad; do \
         if [ -f "$f" ]; then cp -a "$f" /usr/share/nginx/html/; fi; \
       done
