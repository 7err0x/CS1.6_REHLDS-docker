# syntax=docker/dockerfile:1.4
# Serves a GoldSrc-style tree (maps/, sound/, …): baked game image + optional extras volume at runtime.
ARG GAME_IMAGE=cs16-respawn:latest
FROM ${GAME_IMAGE} AS game

FROM nginx:alpine
RUN apk add --no-cache bzip2
COPY docker/fastdl/default.conf /etc/nginx/conf.d/default.conf
COPY docker/fastdl/bzip2-assets.sh /usr/local/bin/bzip2-assets.sh
RUN chmod +x /usr/local/bin/bzip2-assets.sh

SHELL ["/bin/sh", "-exc"]
RUN mkdir -p /built/maps /built/sound /built/models /built/sprites /built/gfx /built/resource /built/overviews
# Mount hlds/ and pick cstrike-base (new layout) or cstrike (older game images).
RUN --mount=type=bind,from=game,source=/opt/steam/hlds,target=/hlds \
    CS=/hlds/cstrike-base; \
    if [ ! -d "$CS/maps" ]; then CS=/hlds/cstrike; fi; \
    for d in maps sound models sprites gfx resource overviews; do \
      if [ -d "$CS/$d" ]; then cp -a "$CS/$d/." "/built/$d/"; fi; \
    done \
    && for f in "$CS"/*.wad; do \
         [ -f "$f" ] || continue; cp -a "$f" /built/; \
       done

COPY docker/fastdl/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
