FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        file \
        unzip \
        unrar-free \
    && rm -rf /var/lib/apt/lists/*

COPY image/scripts/map-download.sh /usr/local/bin/map-download.sh
COPY image/game-assets/map-download-urls.manifest.txt /etc/cs16/map-download-urls.manifest.txt

RUN chmod +x /usr/local/bin/map-download.sh

ENV MANIFEST=/etc/cs16/map-download-urls.manifest.txt \
    OUT_DIR=/out

ENTRYPOINT ["/usr/local/bin/map-download.sh"]
