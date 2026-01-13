FROM docker.io/library/nextcloud:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libmagickcore-6.q16-6-extra \
    exiftool \
    perl \
    && rm -rf /var/lib/apt/lists/*