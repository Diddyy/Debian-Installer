FROM        --platform=$TARGETOS/$TARGETARCH debian:bookworm-slim AS builder

LABEL       author="Josh" maintainer="Diddyy@users.noreply.github.com"

LABEL       org.opencontainers.image.source="https://github.com/Diddyy/Debian-Installer"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive

RUN      apt update && apt upgrade -y \
         && apt -y --no-install-recommends install ca-certificates curl git unzip zip tar jq wget

# Only install the needed steamcmd packages on the AMD64 build
RUN         if [ "$(uname -m)" = "x86_64" ]; then \
                dpkg --add-architecture i386 && \
                apt update && \
                apt -y install lib32gcc-s1 libsdl2-2.0-0:i386; \
            fi
            
# Install Go for building Caddy
RUN wget https://golang.org/dl/go1.12.2.linux-amd64.tar.gz \
    && tar -xvf go1.12.2.linux-amd64.tar.gz \
    && mv go /usr/local \
    && rm go1.12.2.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"

# Install xcaddy
RUN curl -sSL "https://github.com/caddyserver/xcaddy/releases/download/v0.4.0/xcaddy_0.4.0_linux_amd64.tar.gz" | tar -xz -C /usr/local/bin

# Build custom Caddy with Cloudflare DNS module
RUN CGO_ENABLED=1 XCADDY_GO_BUILD_FLAGS="-ldflags '-w -s'" \
    xcaddy build \
    --output frankenphp \
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
