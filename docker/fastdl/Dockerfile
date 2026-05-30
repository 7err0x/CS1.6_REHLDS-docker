# syntax=docker/dockerfile:1.4
# Serves a GoldSrc-style tree (maps/, sound/, …): baked game image + optional extras volume at runtime.
ARG GAME_IMAGE=cs16-respawn:latest
FROM ${GAME_IMAGE} AS game

FROM nginx:alpine
COPY docker/fastdl/default.conf /etc/nginx/conf.d/default.conf

SHELL ["/bin/sh", "-exc"]
RUN mkdir -p /built/maps /built/sound /built/models /built/sprites /built/gfx /built/resource /built/overviews
RUN --mount=type=bind,from=game,source=/opt/steam/hlds/cstrike,target=/cs \
    for d in maps sound models sprites gfx resource overviews; do \
      if [ -d "/cs/$d" ]; then cp -a "/cs/$d/." "/built/$d/"; fi; \
    done \
    && for f in /cs/*.wad; do \
         [ -f "$f" ] || continue; cp -a "$f" /built/; \
       done

COPY docker/fastdl/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
