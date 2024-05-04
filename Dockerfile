FROM        --platform=$TARGETOS/$TARGETARCH debian:bookworm-slim AS builder

LABEL       author="Josh" maintainer="Diddyy@users.noreply.github.com"

LABEL       org.opencontainers.image.source="https://github.com/Diddyy/Debian-Installer"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive

# Update and install necessary packages
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y ca-certificates curl git unzip zip tar jq wget \
    && apt-get install -y build-essential gcc g++ make autoconf libc-dev pkg-config \
    && apt-get install -y php php-cli php-dev libphp-embed
       
# Only install the needed steamcmd packages on the AMD64 build
RUN         if [ "$(uname -m)" = "x86_64" ]; then \
                dpkg --add-architecture i386 && \
                apt update && \
                apt -y install lib32gcc-s1 libsdl2-2.0-0:i386; \
            fi
            
# Install Go for building Caddy
RUN wget https://golang.org/dl/go1.22.2.linux-amd64.tar.gz \
    && tar -xvf go1.22.2.linux-amd64.tar.gz \
    && mv go /usr/local \
    && rm go1.22.2.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"

# Install xcaddy
RUN curl -sSL "https://github.com/caddyserver/xcaddy/releases/download/v0.4.0/xcaddy_0.4.0_linux_amd64.tar.gz" | tar -xz -C /usr/local/bin

# Build custom Caddy with Cloudflare DNS module
RUN CGO_ENABLED=1 XCADDY_GO_BUILD_FLAGS="-ldflags '-w -s'" \
    xcaddy build \
    --output /usr/local/bin/frankenphp \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/dunglas/frankenphp/caddy \
    --with github.com/dunglas/mercure/caddy \
    --with github.com/dunglas/vulcain/caddy

# Runtime stage
FROM debian:bookworm-slim AS runtime

# Copy the binaries from the build stage
COPY --from=builder /usr/local/bin/caddy /usr/local/bin/caddy
COPY --from=builder /usr/local/bin/frankenphp /mnt/server/frankenphp

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
