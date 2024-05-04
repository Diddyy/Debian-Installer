# syntax=docker/dockerfile:1
FROM dunglas/frankenphp:latest-builder AS builder

# Install xcaddy from the official Caddy builder image
COPY --from=caddy:builder /usr/bin/xcaddy /usr/bin/xcaddy

# Enable CGO for building with native extensions
ENV CGO_ENABLED=1 \
    XCADDY_SETCAP=1 \
    XCADDY_GO_BUILD_FLAGS="-ldflags '-w -s'"

# Build FrankenPHP with custom modules including Cloudflare DNS module
RUN xcaddy build \
    --output /usr/bin/frankenphp \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/dunglas/frankenphp=./ \
    --with github.com/dunglas/frankenphp/caddy=./caddy/ \
    --with github.com/dunglas/mercure/caddy \
    --with github.com/dunglas/vulcain/caddy

# Start with a clean stage to reduce final image size
FROM debian:bookworm-slim

# Install any necessary dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libcap2-bin \
    && useradd -m -d /home/container container \
    && rm -rf /var/lib/apt/lists/*

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        --chown=container:container ./../entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT    ["/usr/bin/frankenphp", "run", "--"]
CMD         ["/entrypoint.sh"]
